module.exports = (helpers, log) ->
  parse_torrent = require 'parse-torrent'
  line_reader = require 'line-reader'
  async = require 'async'

  if not helpers.config.get('importer userdir')? and helpers.config.get('importer random userdir torrents') < 1
    log.error 'Importer Worker cannot work with both [userdir] and [random userdir] disabled'
    return undefined
  else
    return async.apply async.waterfall, [
      # Retrieve all paths inside {sultanna path}/import folder
      async.apply helpers.fs.traverseDir, "#{helpers.config.get 'sultanna path'}/import"

      # Filter-out any unknown file types
      (filepaths, next_step) ->
        async.filter filepaths
          , ((path, cb) -> cb path.match /\.(torrent|magnet)$/i)
          , next_step

      # Convert Magnet Links to Torrent files
      (filepaths, next_step) ->
        async.mapLimit filepaths
          , helpers.config.get('importer torrents per batch')
          , (filepath, next_file) ->
            if not filepath.match /\.magnet$/i
              return next_file null, filepath

            async.waterfall [
              # Retrieve Magnet Link from file
              (next) ->
                line_reader.eachLine path, (line) ->
                  next null, line
                  return false

              # Find Torrent metadata
              (magnet, next) ->
                helpers.torrent.get magnet, next

              # Convert to Torrent file Buffer
              (torrent, next) ->
                parsed = torrent.parsedTorrent
                helpers.torrent.remove torrent

                try
                  next null, parsed.infoHash, parse_torrent.toTorrentFile(parsed)
                catch e
                  next e

              # Write to *.torrent file
              (info_hash, buffer, next) ->
                new_filepath = filepath.replace /[^/]+$/, "#{info_hash.toUpperCase()}.torrent"

                fs.outputFile new_filepath, buffer, (err) ->
                  next err, new_filepath

              # Delete *.magnet file
              (new_filepath, next) ->
                helpers.fs.remove filepath, next
            ], (err, new_filepath) ->
              if err
                next_file null, null # Ignore the file entirely
              else
                next_file null, new_filepath
          , (err, new_filepaths) ->
            new_filepaths = new_filepaths.compact()
            skipped = filepaths.length - new_filepaths.length

            log.info "[Importer] Converted #{new_filepaths.length} (skipped #{skipped}) Magnet Links to Torrent Files"

            next_step err, new_filepaths

      # Rename Torrent files to {infoHash}.torrent
      (filepaths, next_step) ->
        async.mapLimit filepaths
          , helpers.config.get('importer torrents per batch')
          , (filepath, next_file) ->
            torrent = parse_torrent filepath

            if not torrent?
              return next_file null, null # Ignore the file entirely

            new_filepath = filepath.replace /[^/]+$/, "#{torrent.infoHash}.torrent"

            if filepath is new_filepath
              next_file null, new_filepath
            else
              helpers.fs.move filepath, new_filepath, {clobber: true}, (err) ->
                if err
                  next_file null, null # Ignore the file entirely
                else
                  next_file null, new_filepath
          , (err, new_filepaths) ->
            new_filepaths = new_filepaths.compact()
            skipped = filepaths.length - new_filepaths.length

            log.info "[Importer] Renamed #{new_filepaths.length} (skipped #{skipped}) Torrent Files to {hash}.torrent"

            next_step err, new_filepaths

      # Calculate userdirs (and locks if required)
      (filepaths, next_step) ->
        files_per_dir = helpers.config.get 'importer random userdir torrents'

        folders_torrents = {}
        folders_locks = {}

        if files_per_dir is 0
          folders_torrents[helpers.user.validHash helpers.config.get 'importer userdir'] = filepaths
        else
          userdirs = filepaths.length / helpers.config.get 'importer random userdir torrents'
          userdirs = Math.floor(userdirs) + 1

          for i in [0...userdirs]
            random_username = (Math.random().toString() + '056127539128').slice(2, 20)
            random_password = (Math.random().toString() + '056127539128').slice(2, 20)

            random_username = helpers.crypto.js.SHA1(random_username).toString()
            random_password = helpers.crypto.js.SHA1(random_password).toString()

            random_userhash = helpers.user.getHash random_username + random_password
            random_userpath = helpers.user.getPath random_userhash

            if helpers.config.enabled 'importer lock random userdir'
              folders_locks["#{random_userpath}/user.lock"] =
                helpers.crypto.user.getLockHash random_username, random_password

            if i + 1 < userdirs
              folders_torrents[random_userpath] =
                filepaths[i * files_per_dir .. i * files_per_dir + files_per_dir]
            else
              folders_torrents[random_userpath] =
                filepaths[i * files_per_dir ..]

        log.info "[Importer] Moving Torrents to #{userdirs ? 'a configured'} userdir..."
        next_step null, folders_torrents, folders_locks

      # Move Torrent files
      (folders_torrents, folders_locks, next_step) ->
        queue = async.queue (work, next) ->
          helpers.fs.move work.tmp, work.dest, next

        queue.concurrency = helpers.config.get 'importer torrents per batch'
        queue.drain = () ->
          log.info "[Importer] Torrents Moved"
          next_step(null, folders_locks)

        for folder, torrents of folders_torrents
          for torrent in torrents
            queue.push torrent
              tmp : torrent
              dest: "#{folder}/#{torrent.match(/[^/]+$/)[1]}"

        if not queue.started() # in case there's no Torrents or something
          queue.drain()

      # Create lock files
      (folder_locks, next_step) ->
        queue = async.queue (work, next) ->
          helpers.fs.outputFile work.path, work.hash, next

        queue.concurrency = helpers.config.get 'importer torrents per batch'
        queue.drain = () ->
          log.info "[Importer] User Locks created"
          next_step()

        for path, hash of folder_locks
          queue.push path: path, hash: hash

        if not queue.started() # in case there's no locks to make
          next_step()
    ]
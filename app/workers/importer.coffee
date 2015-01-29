module.exports = (helpers, cfg, log) ->
  parse_torrent = require 'parse-torrent'
  line_reader = require 'line-reader'
  async = require 'async'

  if not cfg.get('importer userdir')? and cfg.get('importer random userdir torrents') < 1
    log.error 'Importer Worker cannot work with both [userdir] and [random userdir] disabled'
    return undefined
  else
    return async.apply async.waterfall, [
      # Retrieve all paths inside {sultanna path}/import folder
      (next_step) ->
        helpers.fs.traverseDir "#{cfg.get 'sultanna path'}/import", next_step

      # Filter-out any unknown file types
      (filepaths, next_step) ->
        async.filter filepaths
          , (path, _if) ->
            _if path.match /\.(torrent|magnet)$/i
          , (new_filepaths) ->
            log.info "Processing #{new_filepaths.length} Torrents"
            next_step null, new_filepaths

      # Convert Magnet Links to Torrent files
      (filepaths, next_step) ->
        async.mapLimit filepaths
          , cfg.get('importer torrents per batch')
          , (filepath, next_file) ->
            if not filepath.match /\.magnet$/i
              return next_file null, filepath

            async.waterfall [
              # Retrieve Magnet Link from file
              (next) ->
                line_reader.eachLine filepath, (line, last, cb) ->
                  cb false
                  next null, line

              # Find Torrent metadata
              (magnet, next) ->
                helpers.torrent.get magnet, next

              # Convert to Torrent file Buffer
              (torrent_engine, next) ->
                parsed_torrent = torrent_engine.torrent
                torrent_engine.destroy()

                if parsed_torrent?
                  try
                    next null, parsed_torrent.infoHash, parse_torrent.toTorrentFile(parsed_torrent)
                  catch e
                    next e
                else
                  next new Error('blacksam.importer.invalidTorrent')

              # Write to *.torrent file
              (info_hash, buffer, next) ->
                new_filepath = filepath.replace /[^/]+$/, "#{info_hash.toUpperCase()}.torrent"

                helpers.fs.outputFile new_filepath, buffer, (err) ->
                  next err, new_filepath

              # Delete *.magnet file
              (new_filepath, next) ->
                helpers.fs.remove filepath, (err) ->
                  next null, new_filepath
            ], (err, new_filepath) ->
              if err
                next_file null, null
              else
                next_file null, new_filepath
          , (err, new_filepaths) ->
            new_filepaths = new_filepaths.compact()

            converted = (p for p in new_filepaths when p.match /\.magnet$/i).length
            skipped   = (p for p in filepaths when p.match /\.magnet$/i).length - converted

            log.info "Converted #{converted} Magnet Links to Torrent Files (skipped #{skipped})"

            next_step err, new_filepaths

      # Rename Torrent files to {infoHash}.torrent
      (filepaths, next_step) ->
        async.mapLimit filepaths
          , cfg.get('importer torrents per batch')
          , (filepath, next_file) ->
            async.waterfall [
              (next) ->
                helpers.fs.readFile filepath, next

              (torrent_data, next) ->
                torrent = parse_torrent torrent_data

                if torrent?
                  async.nextTick -> next null, filepath.replace(/[^/]+$/, "#{torrent.infoHash.toUpperCase()}.torrent")
                else
                  async.nextTick -> next new Error()

              (new_filepath, next) ->
                if filepath is new_filepath
                  async.nextTick -> next null, new_filepath
                else
                  helpers.fs.move filepath, new_filepath, {clobber: true}, (err) ->
                    next err, new_filepath
            ], (err, new_filepath) ->
              if err
                next_file null, null
              else
                next_file null, new_filepath
          , (err, new_filepaths) ->
            new_filepaths = new_filepaths.compact()

            converted = new_filepaths.length
            skipped   = filepaths.length - converted

            log.info "Renamed #{converted} Torrent Files to {hash}.torrent (skipped #{skipped})"

            next_step err, new_filepaths

      # Calculate userdirs (and locks if required)
      (filepaths, next_step) ->
        if filepaths.length is 0
          return async.nextTick -> next_step null, {}, {}

        files_per_dir = cfg.get 'importer random userdir torrents'

        folders_torrents = {}
        folders_locks = {}

        if files_per_dir is 0
          folders_torrents[helpers.user.validHash cfg.get 'importer userdir'] = filepaths
        else
          userdirs = filepaths.length / cfg.get 'importer random userdir torrents'
          userdirs = Math.floor(userdirs) + 1

          for i in [0...userdirs]
            random_username = (Math.random().toString() + '843910248184').slice(2, 20)
            random_password = (Math.random().toString() + '097654345771').slice(2, 20)

            random_username = helpers.crypto.js.SHA1(random_username).toString()
            random_password = helpers.crypto.js.SHA1(random_password).toString()

            random_userhash = helpers.user.getHash random_username + random_password
            random_userpath = helpers.user.getPath random_userhash

            if cfg.enabled 'importer lock random userdir'
              folders_locks["#{random_userpath}/user.lock"] =
                helpers.crypto.user.getLockHash random_username, random_password

            if i + 1 < userdirs
              folders_torrents[random_userpath] =
                filepaths[i * files_per_dir .. i * files_per_dir + files_per_dir]
            else
              folders_torrents[random_userpath] =
                filepaths[i * files_per_dir ..]

        async.nextTick -> next_step null, folders_torrents, folders_locks

      # Move Torrent files
      (folders_torrents, folders_locks, next_step) ->
        queue =
          for folder, torrents of folders_torrents
            for torrent in torrents
              tmp : torrent
              dest: "#{folder}/#{torrent.match(/[^/]+$/)[0]}"

        async.mapLimit queue.flatten()
          , cfg.get('importer torrents per batch')
          , (item, next) ->
            helpers.fs.move item.tmp, item.dest, (err) ->
              next null, err ? null
          , (err, res) ->
            skipped = res.compact().length
            moved   = res.length - skipped

            log.info "#{moved} Torrents moved (#{skipped} skipped)"
            next_step null, folders_locks

      # Create lock files
      (folder_locks, next_step) ->
        queue =
          for path, hash of folder_locks
            path: path
            hash: hash

        async.mapLimit queue.flatten()
          , cfg.get('importer torrents per batch')
          , (item, next) ->
            helpers.fs.outputFile item.path, item.hash, (err) ->
              next null, err ? null
          , (err, res) ->
            skipped = res.compact().length
            created = res.length - skipped

            log.info "#{created} User Locks created (#{skipped} skipped)"
            next_step()
    ]
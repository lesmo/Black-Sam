module.exports = (helpers, cfg, log) ->
  parse_torrent = require 'parse-torrent'
  line_reader = require 'line-reader'
  async = require 'async'

  cfg =
    sultanna_path: cfg.get 'sultanna path'
    
    userdir: cfg.get 'importer userdir'
    random_userdir_torrents: cfg.get 'importer random userdir torrents'
    lock_random_userdir: cfg.enabled 'importer lock random userdir'

    batch_size: cfg.get 'importer torrents per batch'

  if not cfg.userdir? and cfg.random_userdir_torrents < 1
    log.error 'Importer Worker cannot work with both [userdir] and [random userdir] disabled'
    return undefined
  else
    return (finish) ->
      try
        helpers.fs.ensureDirSync "#{cfg.sultanna_path}/import"
      catch e
        return finish e

      async.waterfall [
        # Retrieve all paths inside {sultanna path}/import folder
        (next_step) ->
          log.verbose "Traversing import directory", path: "#{cfg.sultanna_path}/import"
          helpers.fs.traverseDir "#{cfg.sultanna_path}/import", next_step

        # Filter-out any unknown file types
        (filepaths, next_step) ->
          log.verbose "Filtering non-torrent files...", total: filepaths.length
          async.filter filepaths
            , (path, _if) ->
              _if path.match /\.(torrent|magnet)$/i
            , (new_filepaths) ->
              log.info "Processing #{new_filepaths.length} Torrents"
              next_step null, new_filepaths

        # Convert Magnet Links to Torrent files
        (filepaths, next_step) ->
          log.verbose "Converting *.magnet into *.torrent files..."
          async.mapLimit filepaths
            , cfg.batch_size
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
                  log.verbose "Finding metadata for Magnet Link...", magnet: magnet
                  helpers.torrent.get magnet, next

                # Convert to Torrent file Buffer
                (torrent_engine, next) ->
                  try
                    parsed_torrent = torrent_engine.torrent
                    torrent_engine.destroy()

                    if parsed_torrent?
                      try
                        next null, parsed_torrent.infoHash, parse_torrent.toTorrentFile(parsed_torrent)
                    else
                      next new Error('blacksam.importer.invalidTorrent')
                  catch e
                    next e

                # Write to *.torrent file
                (info_hash, buffer, next) ->
                  new_filepath = filepath.replace /[^/]+$/, "#{info_hash.toUpperCase()}.torrent"

                  helpers.fs.outputFile new_filepath, buffer, (err) ->
                    if not err?
                      log.verbose "Written Torrent file", path: new_filepath
                    next err, new_filepath

                # Delete *.magnet file
                (new_filepath, next) ->
                  helpers.fs.remove filepath, (err) ->
                    if not err?
                      log.verbose "Deleted Magnet file", path: filepath
                    else
                      log.verbose "Error while deleting Magnet file", path: filepath, err

                    next null, new_filepath
              ], (err, new_filepath) ->
                if err
                  log.verbose "Torrent will be skipped (error occured)", {path: filepath, error: err}

                  helpers.torrent.solveConflict filepath, ->
                    next_file null, null
                else
                  log.verbose "Torrent processed", path: new_filepath
                  next_file null, new_filepath
            , (err, new_filepaths) ->
              new_filepaths = new_filepaths.compact()

              converted = (p for p in new_filepaths when p.match /\.magnet$/i).length
              skipped   = (p for p in filepaths when p.match /\.magnet$/i).length - converted

              log.info "Converted #{converted} Magnet Links to Torrent Files (skipped #{skipped})"

              next_step err, new_filepaths

        # Rename Torrent files to {infoHash}.torrent
        (filepaths, next_step) ->
          log.verbose "Renaming *.torrent files to {info_hash}.torrent ...", total: filepaths.length
          async.mapLimit filepaths
            , cfg.batch_size
            , (filepath, next_file) ->
              async.waterfall [
                (next) ->
                  helpers.fs.readFile filepath, next

                (torrent_data, next) ->
                  torrent = parse_torrent torrent_data

                  if torrent?
                    async.nextTick ->
                      next null, filepath.replace(/[^/]+$/, "#{torrent.infoHash.toUpperCase()}.torrent")
                  else
                    async.nextTick ->
                      next new Error()

                (new_filepath, next) ->
                  if filepath is new_filepath
                    async.nextTick ->
                      log.verbose "Torrent already has correct name", path: filepath
                      next null, new_filepath
                  else
                    helpers.fs.move filepath, new_filepath, {clobber: true}, (err) ->
                      if not err?
                        log.verbose "Torrent renamed", path: new_filepath
                      else
                        log.verbose "Torrent renaming failed", err

                      next err, new_filepath
              ], (err, new_filepath) ->
                if err
                  log.verbose "Error ocurred while renaming Torrent", {path: filepath, new_path: new_filepath}
                  next_file null, null
                else
                  log.verbose "Torrent renamed", path: filepath
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
            return async.nextTick ->
              log.verbose "Skipping userdir creation"
              next_step null, {}, {}

          log.verbose "Preparing random userdirs..."

          files_per_dir    = cfg.random_userdir_torrents
          folders_torrents = {}
          folders_locks    = {}

          if files_per_dir is 0
            folders_torrents[helpers.user.validHash cfg.userdir] = filepaths
          else
            userdirs = filepaths.length / cfg.random_userdir_torrents
            userdirs = Math.floor(userdirs) + 1

            for i in [0...userdirs]
              random_username = (Math.random().toString() + '843910248184').slice(2, 20)
              random_password = (Math.random().toString() + '097654345771').slice(2, 20)

              random_username = helpers.crypto.js.SHA1(random_username).toString()
              random_password = helpers.crypto.js.SHA1(random_password).toString()

              random_userhash = helpers.user.getHash random_username + random_password
              random_userpath = helpers.user.getPath random_userhash

              if cfg.lock_random_userdir
                folders_locks["#{random_userpath}/user.lock"] =
                  helpers.crypto.user.getLockHash random_username, random_password

              if i + 1 < userdirs
                folders_torrents[random_userpath] =
                  filepaths[i * files_per_dir .. i * files_per_dir + files_per_dir]
              else
                folders_torrents[random_userpath] =
                  filepaths[i * files_per_dir ..]

              log.verbose "Created %s userdirs (locking: %s)", userdirs.length, cfg.lock_random_userdir

          async.nextTick ->
            next_step null, folders_torrents, folders_locks

        # Move Torrent files
        (folders_torrents, folders_locks, next_step) ->

          queue =
            for folder, torrents of folders_torrents
              for torrent in torrents
                tmp : torrent
                dest: "#{folder}/#{torrent.match(/[^/]+$/)[0]}"
          queue = queue.flatten()

          if queue.length < 1
            log.verbose "No Torrent files to move"
            next_step null, folders_locks
          else
            log.verbose "Moving Torrent files..."

            async.mapLimit queue.flatten()
              , cfg.batch_size
              , (item, next) ->
                log.verbose "Moving Torrent file...", path: item.tmp
                helpers.fs.move item.tmp, item.dest, (err) ->
                  if err?
                    log.verbose "Error while moving Torrent file", err
                  else
                    log.verbose "Torrent file moved", path: item.dest

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
          queue = queue.flatten()

          if queue.length < 1
            next_step()
          else
            log.verbose "Creating user locks..."

            async.mapLimit queue
              , cfg.batch_size
              , (item, next) ->
                helpers.fs.outputFile item.path, item.hash, (err) ->
                  next null, err ? null
              , (err, res) ->
                skipped = res.compact().length
                created = res.length - skipped

                log.info "#{created} User Locks created (#{skipped} skipped)"
                next_step()
      ], finish
###
  Go through all directories in [marianne] and retrieve available Torrents, and
  make sure they're properly Indexed.
###

module.exports = (helpers, cfg, log) ->
  parse_torrent = require 'parse-torrent'
  async = require 'async'
  path = require 'path'

  cfg =
    marianne_path: cfg.get 'marianne path'

    batch_size: cfg.get 'torrent index worker batch'
    update_time_threshold: cfg.get 'torrent update time threshold'

    categories: cfg.get 'categories'

  return (finish) ->
    try
      helpers.fs.ensureDirSync cfg.marianne_path
    catch e
      return finish e

    user_dirs = helpers.fs.readdirSync cfg.marianne_path

    if user_dirs.length < 1
      log.warn "Directory {marianne} contains no User Directories"
      return finish()

    stats =
      users_processed: 0
      users_skipped: 0
      torrents_processed: 0
      torrents_ignored: 0

    async.eachLimit user_dirs
      , cfg.batch_size
      , (user_hash, next_user) ->
        log.verbose "Indexing Torrents in [%s] ...", user_hash

        async.waterfall [
          # Check if it's a valid User Hash dir
          (next_step) ->
            valid_user_hash = helpers.user.validHash user_hash

            if valid_user_hash?
              next_step null, valid_user_hash
            else
              next_step new Error('blacksam.indexer.invalidUserHash')

          # Check if BlackSam-generated-paths match current User Path
          (valid_user_hash, next_step) ->
            current_user_path    = "#{cfg.marianne_path}/#{user_hash}"
            calculated_user_path = "#{cfg.marianne_path}/#{valid_user_hash}"

            if current_user_path is calculated_user_path
              async.nextTick ->
                next_step null, calculated_user_path
            else
              helpers.fs.move current_user_path, calculated_user_path, {clobber: true}, (err) ->
                if err
                  log.error "Unable to rename User Directory [#{user_hash}] to [#{valid_user_hash}]"
                else
                  log.warn "Renamed User Directory [#{user_hash}] to [#{valid_user_hash}]"

                next_step err, calculated_user_path

          # Check if path is a directory (just in case)
          (user_path, next_step) ->
            helpers.fs.lstat user_path, (err, stat) ->
              if stat?.isDirectory()
                next_step err, user_path
              else
                next_step new Error('blacksam.indexer.pathNotDirectory')

          # Retrieve deep files listing
          (user_path, next_step) ->
            helpers.fs.traverseDir user_path, (err, paths) ->
              next_step err, user_path, paths

          # Filter the files to get only valid *.torrent files
          (user_path, file_paths, next_step) ->
            async.filter file_paths
              , (file_path, next) ->
                next file_path.match /[0-9A-F]{40}\.torrent$/
              , (new_file_paths) ->
                if new_file_paths.length > 0
                  next_step null, user_path, new_file_paths
                else
                  next_step new Error('blacksam.indexer.pathEmpty')

          # Process Torrents
          (user_path, file_paths, next_step) ->
            log.info "[Indexer] Processing User Directory [#{user_hash}] (#{file_paths.length} files) ..."

            async.mapLimit file_paths
              , cfg.batch_size
              , (torrent_path, next_file) ->
                async.waterfall [
                  # Calculate categorization of Torrent
                  (next_index_step) ->
                    torrent_subpath = torrent_path.from user_path.length
                    [..., category, subcategory, nil] = torrent_subpath.split path.sep

                    if not subcategory?
                      category = 'others'

                    if not category?
                      [category, subcategory] = [subcategory, '']

                    category    = category.toLowerCase()
                    subcategory = category.toLowerCase()

                    if not cfg.categories[category]?
                      return next_index_step new Error('blacksam.indexer.invalidTorrentCategorization')

                    if subcategory isnt '' and not cfg.categories[category].any(subcategory)
                      return next_index_step new Error('blacksam.indexer.invalidTorrentCategorization')

                    next_index_step null, category, subcategory

                  # Open Torrent's file Buffer
                  (category, subcategory, next_index_step) ->
                    helpers.fs.readFile torrent_path, (err, torrent_buffer) ->
                      next_index_step err, torrent_buffer, category, subcategory

                  # Parse Torrent and assert hash matches file name
                  (torrent_buffer, category, subcategory, next_index_step) ->
                    try
                      torrent = parse_torrent torrent_buffer
                    catch e
                      return async.nextTick ->
                        next_index_step new Error('blacksam.indexer.torrentParseError')

                    file_hash = torrent_path.match /([0-9A-F]{40})\.torrent$/

                    if not file_hash?
                      return async.nextTick ->
                        next_index_step new Error('blacksam.indexer.invalidFileName')

                    if file_hash[1] is torrent.infoHash.toUpperCase()
                      next_index_step null, torrent, category, subcategory
                    else
                      calculated_torrent_path = helpers.torrent.getPath user_hash
                        , category
                        , subcategory
                        , torrent.infoHash

                      if calculated_torrent_path?
                        helpers.fs.move torrent_path, calculated_torrent_path, (err) ->
                          if not err?
                            torrent_path = calculated_torrent_path

                          next_index_step err, torrent, category, subcategory
                      else
                        async.nextTick ->
                          next_index_step new Error('blacksam.indexer.invalidFileName')

                  # Determine if it's in the Search Index and update accordingly
                  (torrent, category, subcategory, next_index_step) ->
                    async.waterfall [
                      # Get the Torrent in the Search Index
                      (next) ->
                        helpers.search.index.get torrent.infoHash, (err, torrent_json) ->
                          if err
                            next new Error('blacksam.indexer.notIndexed'), torrent
                          else
                            try
                              next null, JSON.parse torrent_json
                            catch e
                              next e

                      # Determine if it's correctly located in filesystem
                      (torrent, next) ->
                        indexed_torrent_path = helpers.torrent.getPath torrent

                        if not indexed_torrent_path?
                          async.nextTick -> next new Error('blacksam.indexer.invalidTorrentInIndex'), torrent
                        else if torrent_path is indexed_torrent_path
                          async.nextTick -> next null, torrent
                        else
                          helpers.fs.move torrent_path, indexed_torrent_path, (err) ->
                            if not err?
                              torrent_path = indexed_torrent_path

                            next err, torrent

                      # Determine if it should be updated
                      (torrent, next) ->
                        torrent_last_accessed = new Date torrent.accessed
                        torrent_last_updated  = new Date torrent.updated
                        time_threshold = cfg.update_time_threshold

                        if torrent_last_accessed > torrent_last_updated.advance time_threshold
                          next null, torrent
                        else
                          next new Error('blacksam.importer.itemUpdateNotNeeded')
                    ], (err, torrent) ->
                      switch err?.message ? 'blacksam.indexer.notIndexed'
                        when 'blacksam.indexer.notIndexed'
                          next_index_step null, torrent, category, subcategory
                        when 'blacksam.importer.itemUpdateNotNeeded'
                          next_index_step null
                        else
                          next_index_step err

                  # Scrape Trackers for seed-leech data
                  (torrent, category, subcategory, next_index_step) ->
                    helpers.torrent.scrape torrent.infoHash, (err, data) ->
                      next_index_step null, torrent, data, category, subcategory # errors are ignored

                  # Add/Update Search Index
                  (torrent, data, category, subcategory, next_index_step) ->
                    torrent.category    = category
                    torrent.subcategory = subcategory

                    torrent.seeders  = data.complete
                    torrent.leechers = data.incomplete

                    helpers.search.indexTorrent torrent, (err) ->
                      next_index_step err, torrent
                ], (err, torrent) ->
                  if not err?
                    return next_file null, torrent

                  if not torrent?
                    return next_file null, null

                  if err.message is 'blacksam.indexer.invalidTorrentInIndex'
                    # If there's a Torrent in the index that generated invalid path,
                    # delete it from the Search Index and solve it as a conflict
                    async.parallel [
                      async.apply helpers.search.index.del, torrent.id
                      async.apply helpers.torrent.solveConflict, torrent_path
                    ], ->
                      log.warn "Invalid ID [%s] removed from Index", torrent.id
                      next_file null, null
                  else if err.message?.match /^blacksam\.indexer/
                    # If whatever error is triggered internally, at BlackSam level
                    # it's considered a conflict
                    helpers.torrent.solveConflict torrent_path, ->
                      log.warn "Unexpected error processing [%s] resolved as conflict", torrent.id
                      next_file null, null
                  else
                    next_file err
              , next_step
        ], (err, torrents) ->
          if torrents?
            stats.torrents_processed +=
              processed = torrents.compact().length
            stats.torrents_skipped +=
              skipped = torrents.length - processed
          else
            processed = skipped = 0

          if err?
            switch err.message
              when 'blacksam.indexer.invalidUserHash'
                sub_err = 'invalid user hash'
              when 'blacksam.indexer.pathNotDirectory'
                sub_err = 'not a directory'
              when 'blacksam.indexer.pathEmpty'
                sub_err = 'no torrent files found'
              else
                sub_err = 'unexpected'

            log.warn "User directory [#{user_hash}] skipped: #{sub_err}",
              processed: processed
              skipped  : skipped

            stats.users_skipped++
          else
            log.warn "User directory [#{user_hash}] processed",
              processed: processed
              skipped  : skipped

            stats.users_processed++

          next_user()
      , (err) ->
        if err
          log.error "Indexing failed", stats
          finish err
        else
          log.info "Indexing finished", stats
          finish()
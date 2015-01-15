###
  Go through all directories in [marianne] and retrieve available Torrents, and
  make sure they're properly Indexed.

  NOTE: I know this might not be the most-readable piece of code, but works.
###

module.exports = (helpers, log) ->
  parse_torrent = require 'parse-torrent'
  async = require 'async'
  path = require 'path'
  fs = require 'fs-extra'

  find_file_meta = (filepath, userhash) -> (done) ->
    if not userhash?
      log.error "Userhash [#{userhash}] invalid, skipping"
      return done()

    info_hash = path.basename(filepath).match(/(.*)\..*/i)[1].toUpperCase()
    parsed_torrent = parse_torrent fs.readFileSync filepath

    category = path.basename path.dirname filepath
    category = if category is userhash then 'others' else category.toLowerCase()

    subcategory = path.basename path.dirname path.dirname filepath
    subcategory = if subcategory is userhash then '' else subcategory.toLowerCase()

    created = null

    ignore_torrent_file = ->
      if helpers.config.get('torrent conflict solution') is 'delete'
        fs.delete filepath, (err) ->
          if err
            log.error "Torrent [#{info_hash}] conflict solving failed", err
          else
            log.info "Torrent [#{info_hash}] conflict solved through deletion",
              file: filepath
          done()
      else if helpers.config.get('torrent conflict solution') is 'rename'
        fs.move filepath, "#{filepath}.#{helpers.config.get 'torrent conflict extension'}", (err) ->
          if err
            log.error "Torrent [#{info_hash}] conflict solving failed", err
          else
            log.error "Torrent [#{info_hash}] conflict solved by renaming",
              renamed: "#{filepath}.#{helpers.config.get 'torrent conflict extension'}"
          done()
      else
        log.error "Torrent [#{info_hash}] conflict WILL NOT be solved, configuration is invalid"
        done()

    get_torrent_description = ->
      if fs.existsSync "#{helpers.torrent.getLocalPath find_torrent_meta}.md"
        torrent_description = fs.readFileSync "#{helpers.torrent.getLocalPath find_torrent_meta}.md", 'utf8'
        torrent_meta.description = torrent_description.parameterize().spacify()

    find_torrent_meta = ->
      if helpers.config.get('categories')[category]?
        if subcategory.length > 0
          if helpers.config.get('categories')[category].indexOf(subcategory) < 0
            log.warn "Torrent [#{info_hash}] Category [#{category}.#{subcategory}] not in configuration, ignoring"
            return ignore_torrent_file() # Subcategory is ignored
      else
        log.warn "Torrent [#{info_hash}] Category [#{category}] not in configuration, ignoring"
        return ignore_torrent_file() # Category is ignored

      helpers.torrent.findMetadata parsed_torrent, (err, torrent_meta) ->
        return ignore_torrent_file() if not torrent_meta?

        torrent_meta.uploader    = userhash
        torrent_meta.category    = category
        torrent_meta.subcategory = subcategory

        torrent_meta.created = created if created?

        torrent_path = "#{helpers.torrent.getLocalPath torrent_meta}.torrent"

        if torrent_path isnt filepath
          log.warn "Torrent [#{info_hash}] has incorrect path, moving ...", {
            original: filepath,
            corrected: torrent_path
          }

          fs.move filepath, torrent_path, clobber: true, (err) ->
            if err
              log.error "Torrent [#{info_hash}] move failed", err
              done()
            else
              log.info "Torrent [#{info_hash}] move successful"
              get_torrent_description()
              done null, torrent_meta
        else
          get_torrent_description()
          done null, torrent_meta

    if helpers.torrent.validHash(info_hash) and info_hash is parsed_torrent.infoHash.toUpperCase()
      helpers.search.index.get info_hash, (err, _torrent_meta) ->
        if err or not _torrent_meta?
          log.info "Torrent [#{info_hash}] not in Index"
        else
          _torrent_meta = JSON.parse _torrent_meta
          delete _torrent_meta['*']

          console.log _torrent_meta

          torrent_last_accessed = new Date _torrent_meta.accessed
          torrent_last_updated  = new Date _torrent_meta.updated
          created = new Date _torrent_meta.created

          time_threshold = helpers.config.get 'torrent update time threshold'

          if torrent_last_accessed < torrent_last_updated.advance time_threshold
            log.info "Torrent [#{info_hash}] already in Index, won't be updated"
            return done() # Don't update torrent until accessed later

          # Trust what's already in the index, and not new stuff
          if _torrent_meta.uploader isnt userhash
            log.warn "Torrent [#{info_hash}] file found in different User Folder (will be moved to [#{_torrent_meta.uploader}])"
            userhash = _torrent_meta.uploader
          if _torrent_meta.category isnt category
            log.warn "Torrent [#{info_hash}] file found in different Category (will be moved to [#{_torrent_meta.category}])"
            category = _torrent_meta.category
          if _torrent_meta.subcategory isnt subcategory
            log.warn "Torrent [#{info_hash}] file found in different Subcategory (will be moved to [#{_torrent_meta.subcategory}])"
            subcategory = _torrent_meta.subcategory

          log.info "Torrent [#{info_hash}] already in Index, updating ..."

        find_torrent_meta()
    else
      log.info "Invalid infohash [#{info_hash}] expected [#{parsed_torrent.infoHash}]"
      find_torrent_meta()

  get_files = (dirpath, files) ->
    for item in fs.readdirSync dirpath
      stat = fs.lstatSync "#{dirpath}/#{item}"

      if stat.isDirectory()
        get_files "#{dirpath}/#{item}", files
      else if stat.isFile() and item.match /\.torrent$/
        files.push "#{dirpath}/#{item}"

  return (finish) ->
    if not fs.existsSync helpers.config.get 'marianne path'
      log.warn "Marianne Folder doesn't exist, creating...",
        path: helpers.config.get 'marianne path'

      fs.mkdirpSync helpers.config.get 'marianne path'
      return setTimeout finish, helpers.config.get 'indexer timespan'

    user_dirs = fs.readdirSync helpers.config.get 'marianne path'

    if user_dirs.length < 1
      log.info "Marianne Folder contains no folders"
      return setTimeout finish, helpers.config.get 'indexer timespan'

    stats =
      users_processed: 0
      users_skipped: 0
      torrents_processed: 0
      torrents_ignored: 0

    worker = async.cargo (tasks, callback) ->
      async[helpers.config.get 'torrent index worker method'] tasks, (err, torrents) ->
        valid_torrents = (t for t in torrents when t?)

        log.info "Indexing batch of #{valid_torrents.length} Torrents " +
          "(#{torrents.length - valid_torrents.length} ignored) ..."

        stats.torrents_processed += valid_torrents.length
        stats.torrents_ignored += torrents.length - valid_torrents.length

        helpers.search.indexTorrent valid_torrents, (err) ->
          if err
            log.error "Batch of #{valid_torrents.length} Torrents processing failed", err
          else
            log.info "Batch of #{valid_torrents.length} Torrents processing successful"

          callback()

    worker.payload = 0

    async.eachLimit user_dirs
      , helpers.config.get('torrent index worker batch')
      , (user_dir, next) ->
        valid_user_dir = helpers.user.validHash user_dir

        if fs.lstatSync("#{helpers.config.get 'marianne path'}/#{user_dir}").isDirectory() and valid_user_dir
          stats.users_processed++

          process_files = ->
            files = []
            get_files "#{helpers.config.get 'marianne path'}/#{user_dir}", files

            if files.length > 0
              log.info "Processing [#{user_dir}] (#{files.length} torrents found)..."
              for file in files
                # Dynamically increase payload size until configured batch size is reached
                if worker.payload <= helpers.config.get 'torrent index worker batch'
                  worker.payload++

                worker.push find_file_meta file, user_dir

              # Move to the next User until current one is indexed
              worker.drain = next
            else
              next()

          if "#{helpers.config.get 'marianne path'}/#{user_dir}" isnt "#{helpers.config.get 'marianne path'}/#{valid_user_dir}"
            fs.move "#{helpers.config.get 'marianne path'}/#{user_dir}"
              , "#{helpers.config.get 'marianne path'}/#{helpers.user.validHash user_dir}"
              , clobber: true
              , (err) ->
                if err
                  log.error "Unable to rename [#{user_dir}] to [#{valid_user_dir}], skipping"
                  next()
                else
                  log.warn "User Folder [#{user_dir}] had invalid User Hash formatting, renamed to [#{valid_user_dir}]..."
                  user_dir = valid_user_dir
                  process_files()
          else
            process_files()
        else
          log.warn "Skipped [#{user_dir}]"
          stats.users_skipped++
          next()
      , ->
        log.info "Torrents indexing Work queueing finished"

        worker.drain = ->
          log.info "Torrents indexing finished", stats
          setTimeout finish, helpers.config.get 'indexer timespan'

        # If there's nothing, setup next call
        worker.drain() if worker.length() is 0
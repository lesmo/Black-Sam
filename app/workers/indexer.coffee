###
  Go through all directories in [marianne] and retrieve available Torrents, and
  make sure they're properly Indexed.
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

    category = (path.basename path.dirname filepath).toLowerCase()
    category = 'others' if category is userhash

    subcategory = (path.basename path.dirname path.dirname filepath).toLowerCase()
    subcategory = '' if subcategory is userhash

    if helpers.torrent.validHash(info_hash) and info_hash is parsed_torrent.infoHash
      helpers.search.index.get info_hash, (err, _torrent_meta) ->
        if not err? and _torrent_meta?
          torrent_last_accessed = new Date _torrent_meta.health.accessed
          torrent_last_updated  = new Date _torrent_meta.health.updated
          time_threshold = helpers.config.get 'torrent update time threshold'

          if torrent_last_accessed < torrent_last_updated.advance time_threshold
            log.info "Torrent [#{info_hash}] already in Index, won't be updated"
            return done() # Don't update torrent until accessed later

          # Trust what's already in the index, and not new stuff
          if _torrent_meta.uploader isnt userhash
            log.warn "Torrent [#{info_hash}] file found in different User Folder (will be moved to [#{_torrent_meta.uploader}]"
            userhash = _torrent_meta.uploader
          if _torrent_meta.category isnt category
            log.warn "Torrent [#{info_hash}] file found in different Category (will be moved to [#{_torrent_meta.category}]"
            category = _torrent_meta.category
          if _torrent_meta.subcategory isnt subcategory
            log.warn "Torrent [#{info_hash}] file found in different Subcategory (will be moved to [#{_torrent_meta.subcategory}]"
            subcategory = _torrent_meta.subcategory

        find_torrent_meta()
    else
      find_torrent_meta()

    find_torrent_meta = () ->
      if helpers.config.get('categories')[category]?
        if subcategory.length > 0
          if helpers.config.get('categories')[category].indexOf(subcategory) < 0
            log.warn "Torrent [#{info_hash}] Category [#{category}.#{subcategory}] not in configuration, ignoring"
            return ignore_torrent_file() # Subcategory is ignored
      else
        log.warn "Torrent [#{info_hash}] Category [#{category}] not in configuration, ignoring"
        return ignore_torrent_file() # Category is ignored

      helpers.torrent.findMetadata parsed_torrent, (err, torrent_meta) ->
        if torrent_meta?
          torrent_meta.uploader    = userhash
          torrent_meta.category    = category
          torrent_meta.subcategory = subcategory

          torrent_path = helpers.torrent.getLocalPath torrent_meta

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
                done null, torrent_meta
          else
            done null, torrent_meta
        else
          ignore_torrent_file()

    ignore_torrent_file = () ->
      if helpers.config.get 'torrent conflict solution' is 'delete'
        fs.delete filepath, (err) ->
          if err
            log.error "Torrent [#{info_hash}] conflict solving failed", err
          else
            log.info "Torrent [#{info_hash}] conflict solved through deletion",
              file: filepath
          done()
      else if helpers.config.get 'torrent conflict solution' is 'rename'
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

  get_files = (dirpath, files) ->
    for item in fs.readdirSync dirpath
      stat = fs.lstatSync(item)

      if stat.isDirectory()
        get_files "#{dirpath}/#{item}", files
      else if stat.isFile() and item.match /\.torrent$/
        files.push "#{dirpath}/#{item}"

  return (finish) ->
    worker = async.cargo (tasks, callback) ->
      async[helpers.config.get 'torrent index worker method'] (err, torrents) ->
        valid_torrents = (t for t in torrents when t?)

        log.info "Indexing batch of #{valid_torrents.length} Torrents (#{torrents.length - valid_torrents.length} ignored) ...",
          torrents: torrents

        helpers.search.indexTorrent valid_torrents, (err) ->
          if err
            log.error "Batch of #{valid_torrents.length} Torrents processing failed", err
          else
            log.info "Batch of #{valid_torrents.length} Torrents processing successful"

          callback()

    worker.payload = helpers.config.get 'torrent index worker batch'

    async.eachLimit fs.readdirSync(helpers.config.get 'marianne path')
      , helpers.config.get('torrent index worker batch')
      , (user_dir, next) ->
        return next() if not fs.lstatSync("#{marianne}/#{user_dir}").isDirectory()
        return next() if not helpers.user.validHash user_dir

        files = []
        get_files "#{marianne}/#{user_dir}", files

        for file in files
          worker.push find_file_meta(file, user_dir)
      , ->
        log.info "Torrents indexing Work queueing finished"
        worker.drain = ->
          log.info "Torrents indexing finished"
          setTimeout finish, app.get('indexer timespan')
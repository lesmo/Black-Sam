module.exports = (helpers, cfg, log) ->
  string_decoder = new (require 'string_decoder').StringDecoder('utf8')
  parse_torrent  = require 'parse-torrent'
  async          = require 'async'
  path           = require 'path'

  TorrentStream = require 'torrent-stream'
  Tracker       = require 'node-tracker'

  trackers =
    for url in cfg.get 'torrent trackers'
      new Tracker url

  cfg =
    marianne_path: cfg.get 'marianne path'
    sultanna_path: cfg.get 'sultanna path'

    conflict_solution: cfg.get 'torrent conflict solution'
    conflict_rename_ext: cfg.get 'torrent conflict extension'

    torrent_trackers: cfg.get 'torrent trackers'
    timeout: cfg.get 'torrent process timeout'

  ###
    Facilitates processing Torrents and their metadata.
  ###
  class TorrentHelper
    ###
      Validates that a given String is a (possibly) valid InfoHash.

      @param hash (String) Hash to validate
      @returns (Boolean)
    ###
    @validHash = (hash) -> not not hash.match /^([0-9a-f]{40}|[0-9a-z]{32})$/i

    ###
      Calculates the Path a Torrent file(s) should be located at given
      it's uploader, categories and info-hash.

      @param userhash (String|Object) User Hash of the uploader, or a Indexable Torrent object.
      @param category (String) Category of the Torrent.
      @param subcategory (String) Sub-category of the Torrent.
      @param hash (String) The info-hash of the Torrent.
    ###
    @getPath = @getLocalPath = (userhash, cat..., hash) ->
      if hash?
        # Called as getPath(userhash, [category], [subcategory], hash)
        [category, subcategory] = [cat[0] ? '', cat[1] ? '']
      else if typeof userhash is 'object'
        # Called as getPath(torrent)
        return @getPath torrent.uploader
          , torrent.category
          , torrent.subcategory
          , torrent.id
      else
        # Called in a retarded way
        return undefined

      userhash = helpers.user.validHash(userhash)

      if not userhash? or @validHash hash
        return undefined

      category    = category.toUppperCase()
      subcategory = subcategory.toUpperCase()
      hash        = hash.toUpperCase()

      return path.join cfg.marianne_path,
        userhash,
        category,
        subcategory,
        hash

    ###
      Find a Torrent in a Tracker, or via DHT, and return it in a callback.
      It's resource is not released nor removed from the list, that should be
      done manually unless an error occurred. Check the methods below this one
      for examples.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @get = (torrent_id, callback) ->
      try
        if torrent_id.infoHash?
          torrent_id = parse_torrent.toTorrentFile torrent_id

        torrent_engine = TorrentStream torrent_id,
          tmp     : cfg.sultanna_path
          trackers: cfg.torrent_trackers

        torrent_engine.once 'ready', ->
          if timeout?
            clearTimeout timeout
            callback null, torrent_engine

        timeout = setTimeout ->
          clearTimeout timeout
          timeout = undefined

          torrent_engine.removeAllListeners? 'ready'

          if torrent_engine?.destroy?
            torrent_engine.destroy ->
              callback new Error('blacksam.torrent.getTimeout')
          else
            callback new Error('blacksam.torrent.getTimeout')
        , cfg.timeout
      catch e
        return async.nextTick ->
          callback e
    @scrape = (tracker_urls..., torrent_engine, callback) ->
      try
        info_hash = (torrent_engine?.torrent?.infoHash) ? (torrent_engine?.infoHash) ? (parse_torrent(torrent_engine)?.infoHash)

        if not info_hash?
          throw new Error()
      catch e
        return async.nextTick ->
          callback new Error('blacksam.torrent.scrape.invalidTorrent')

      if tracker_urls.length > 0
        trackers = tracker_urls.flatten()
      else
        trackers = cfg.torrent_trackers.randomize()
        tmp_trackers = []

        if torrent.announce?.length > 0
          tmp_trackers = tmp_trackers.include torrent.announce

        if torrent.announceList?.length > 0
          tmp_trackers = tmp_trackers.include torrent.announceList

      data =
        announce: undefined
        complete: -1
        incomplete: -1

      async.eachSeries trackers.include(tmp_trackers, 0)
        , (tracker, next) ->
          if Object.isString tracker
            tracker = new Tracker tracker

          tracker.scrape info_hash, {timeout: cfg.timeout}, (err, d) ->
            if err?
              next null
            else
              data = Object.merge d, announce: "#{tracker.trackerUri}/announce"
              next 'found.it'
        , (err) ->
          tmp_trackers =
            tmp_trackers.filter (i) -> typeof i is 'object'

          if tmp_trackers.length > 0
            async.each tmp_trackers
              , (tracker, next) ->
                log.verbose "Closing Tracker...", tracker: tracker.trackerUri

                tracker.close()
                next()
              , ->
                log.verbose "Closed temporal Trackers"

          if err?.message is 'found.it'
            log.verbose "Scrape completed for [%s]", info_hash, data
          else
            log.verbose "Scrape failed for [%s]", info_hash, data

          callback null, data

    @getIndexable = (torrent) ->
      indexable_files_string =
        (file.path for file in torrent.files)
        .join(' ')
        .parameterize()
        .spacify()
        .split(' ')
        .unique()
        .join(' ')
        .compact()
      indexable_name_string =
        torrent.name
        .parameterize()
        .spacify()
        .compact()

      return {
        id: torrent.infoHash.toUpperCase()
        magnet: parse_torrent.toMagnetURI torrent
        uploader: undefined

        title: torrent.name
        title_ix: indexable_name_string
        description: ''

        category: 'other'
        subcategory: ''

        files_ix: indexable_files_string
        files: (file.path for file in torrent.files)

        seeders : -1
        leechers: -1
        indexed : new Date().getTime()
        updated : new Date().getTime()
        accessed: new Date().getTime()
      }

    ###
      Find a Torrent's Metadata and return an Indexable Torrent, used for
      Search Indexing. Only {uploader}, {category} and {subcategory} cannot be
      set by this method and they'll reference an undefined uploader account
      and the "Others" category, with no sub-category.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @findMetadata = (torrent_id, callback) ->
      async.waterfall [
        (next) =>
          @get torrent_id, next

        (torrent_engine, next) =>
          @scrape torrent_engine.torrent, (err, data) ->
            next err, torrent_engine, data

        (torrent_engine, data, next) =>
          indexable_metadata = @getIndexable torrent_engine.torrent
          indexable_metadata.seeders  = data.complete
          indexable_metadata.leechers = data.incomplete

          next null, indexable_metadata, torrent_engine
      ], (err, indexable_metadata, torrent_engine) ->
        if torrent_engine?.destroy?
          torrent_engine.destroy ->
            callback err, indexable_metadata
        else
          callback err, indexable_metadata


    ###
      Check if a given Torrent exists. Simply that.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @exists = (torrent_id, callback) ->
      @get torrent_id, (err, torrent_engine) ->
        if torrent_engine?.destroy?
          torrent_engine.destroy ->
            callback not err? and torrent?
        else
          callback not err? and torrent?

    if cfg.conflict_solution is 'delete'
      @solveConflict = (torrent_path, callback) ->
        helpers.fs.remove torrent_path, callback
    else if cfg.conflict_solution is 'rename'
      @solveConflict = (torrent_path, callback) ->
        helpers.fs.move torrent_path, "#{torrent_path}.#{cfg.conflict_rename_ext}", callback
    else
      log.error "Invalid conflict solution {#{cfg.conflict_solution}}"
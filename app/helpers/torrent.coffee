module.exports = (helpers, cfg, log) ->
  string_decoder = new (require 'string_decoder').StringDecoder('utf8')
  parse_torrent  = require 'parse-torrent'
  async          = require 'async'
  path           = require 'path'

  TorrentStream = require 'torrent-stream'
  Tracker       = require 'node-tracker'
  Timeout       = require 'node-timeout'

  torrent_timeout =
    Timeout cfg.get('torrent process timeout'),
      err: new Error('blacksam.torrent.processTimeout')

  trackers =
    for url in cfg.get 'torrent trackers'
      new Tracker("#{url}#{if not url.endsWith('/announce') then '/announce'}")

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

      return path.join cfg.get('marianne path'),
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
      if torrent_id.infoHash?
        torrent_id = parse_torrent.toTorrentFile torrent_id

      torrent_engine = TorrentStream torrent_id,
        tmp     : cfg.get 'sultanna path'
        trackers: cfg.get 'torrent trackers'

      torrent_engine.once 'ready', (err) ->
        if err?
          torrent_engine.destroy ->
            callback err
        else
          callback null, torrent_engine

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
        trackers = cfg.get 'torrent trackers'

        if torrent.announceList?.length > 0
          trackers = trackers.include torrent.announceList, 0
        if torrent.announce?.length > 0
          trackers = trackers.include torrent.announce, 0

      async.map trackers
        , (tracker, next_tracker) ->
          tracker.scrape info_hash, (err, data) ->
            if err?
              next_tracker null, null
            else
              next_tracker err, Object.merge(data, announce: tracker.trackerUri)
        , (err, data) ->
          if err?
            callback err, data
          else
            data = data.compact()

            if data.length is 0
              callback null,
                announce: undefined
                complete: -1
                incomplete: -1
            else
              callback null, data[0]

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
        torrent_engine.destroy ->
          callback err, indexable_metadata

    ###
      Check if a given Torrent exists. Simply that.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @exists = (torrent_id, callback) ->
      @get torrent_id, (err, torrent_engine) ->
        torrent_engine.destroy ->
          callback not err? and torrent?
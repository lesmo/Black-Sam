module.exports = (helpers, cfg, log) ->
  string_decoder = new (require 'string_decoder').StringDecoder('utf8')
  parse_torrent = require 'parse-torrent'
  async = require 'async'
  path = require 'path'

  Timeout = require('node-timeout')
  Tracker = require('bittorrent-tracker').Client

  torrent_timeout = Timeout cfg.get('torrent process timeout'), err: new Error('blacksam.torrent.processTimeout')

  ###
    Facilitates processing Torrents and their metadata.
  ###
  class TorrentHelper
    ### WebTorrent Client Instance ###
    @client = new require('webtorrent') tracker: cfg.get 'torrent trackers'

    ###
      Validates that a given String is a (possibly) valid InfoHash.

      @param hash (String) Hash to validate
      @returns (Boolean)
    ###
    @validHash = (hash) -> not not hash.match /^([0-9a-f]{40}|[0-9a-z]{32})$/i

    ###
      Calculates the Path a Torrent file(s) should be located at given
      it's uploader, categories and info-hash.

      @param userhash (String|Object) User Hash of the uploader, or a Torrent Metadata object.
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

    @remove = (torrent_id) ->
      torrent = @client.get torrent_id

      if torrent?
        torrent.destroy()
        @client.remove torrent.infoHash ? torrent

    ###
      Find a Torrent in a Tracker, or via DHT, and return it in a callback.
      It's resource is not released nor removed from the list, that should be
      done manually unless an error occurred. Check the methods below this one
      for examples.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @get = (torrent_id, callback) ->
      try
        torrent_id = parse_torrent torrent_id
      catch e
        return async.nextTick -> callback e

      @client.add torrent_id, {tmp: cfg.get 'sultanna path'}, torrent_timeout (torrent) =>
        if torrent is 'blacksam.torrent.processTimeout' or not torrent?
          log.warn "Metadata retrieval for Torrent [#{torrent?.infoHash or 'removed'}] timed-out"
          @remove torrent

          if torrent is 'blacksam.torrent.processTimeout'
            callback new Error('blacksam.torrent.processTimeout')
          else
            callback new Error('blacksam.torrent.notFound')
        else
          callback null, torrent

    @findTrackers = (torrent, count..., callback) ->
      trackers_searching = cfg.get 'torrent trackers'
      trackers_found = []

      count = count[0] ? 3
      count = 1 if count < 1

      for tracker_url in trackers_searching
        @scrape tracker_url, torrent.infoHash, (err, torrent, data) ->
          return if err
          return if trackers_found.length is count

          trackers_found.add data.announce

          if trackers_searching.length is 0
            callback new Error('blacksam.torrent.noTrackerForTorrent')
          else
            callback null, trackers_found

    @scrape = (tracker_urls..., torrent, callback) ->
      try
        info_hash = torrent?.infoHash ? parse_torrent(torrent).infoHash

        if not info_hash?
          throw new Error()
      catch e
        return async.nextTick -> callback new Error('blacksam.torrent.scrape.invalidTorrent')

      if tracker_urls.length > 0
        trackers = tracker_urls.flatten()
      else
        trackers = cfg.get('torrent trackers')

        if torrent.announceList?.length > 0
          trackers = trackers.include torrent.announceList, 0
        if torrent.announce?.length > 0
          trackers = trackers.include torrent.announce, 0

      async.detect trackers.compact()
        , (tracker_url, win) ->
          Tracker.scrape tracker_url, info_hash, (err, data) ->
            win err ? Object.merge(data, announce: tracker_url)
        , torrent_timeout (data) ->
          if data.announce?
            callback null, data
          else
            callback data,
              announce: undefined
              complete: -1
              incomplete: -1

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
        torrent.parsedTorrent.name
        .parameterize()
        .spacify()
        .compact()

      return {
        id: torrent.infoHash.toUpperCase()
        magnet: parse_torrent.toMagnetURI torrent.parsedTorrent
        uploader: undefined

        title: torrent.parsedTorrent.name
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
      Find a Torrent's Metadata and return a Torrent Metadata Object, used for
      Search Indexing. Only {uploader}, {category} and {subcategory} cannot be
      set by this method and they'll reference an undefined uploader account
      and the "Others" category, with no sub-category.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @findMetadata = (torrent_id, callback) ->
      async.waterfall [
        (next) =>
          @get torrent_id, next
        (torrent, next) =>
          @scrape torrent, next
        (torrent, data, next) =>
          indexable_metadata = @getIndexable torrent
          indexable_metadata.seeders  = data.complete
          indexable_metadata.leechers = data.incomplete

          next null, indexable_metadata, torrent
      ], (err, indexable_metadata, torrent) =>
        async.nextTick ->
          callback err, indexable_metadata, torrent.parsedTorrent

        @remove torrent?.infoHash

    ###
      Check if a given Torrent exists. Simply that.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @exists = (torrent_id, callback) ->
      @get torrent_id, (err, torrent) =>
        @remove torrent
        callback not err? and torrent?
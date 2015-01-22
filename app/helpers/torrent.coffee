module.exports = (helpers, cfg, log) ->
  string_decoder = new (require 'string_decoder').StringDecoder('utf8')
  parse_torrent = require 'parse-torrent'
  path = require 'path'

  ###
    Facilitates processing Torrents and their metadata.
  ###
  class torrent_helper
    ### WebTorrent Client Instance ###
    @client = new require('webtorrent')()

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
    @getPath = @getLocalPath = (userhash, category, subcategory, hash) ->
      if userhash? and category? and subcategory?
        if not hash?
          hash = subcategory
          subcategory = null
      else if typeof userhash is 'object'
        torrent = userhash
        userhash = torrent.uploader
        category = torrent.category
        subcategory = torrent.subcategory
        hash = torrent.id
      else
        console.log userhash
        return undefined

      return path.join cfg.get('marianne path'),
        helpers.user.validHash(userhash),
        category.toUpperCase(),
        (subcategory ? '').toUpperCase(),
        hash.toUpperCase()

    @remove = (torrent_id) ->
      return if not torrent_id?

      torrent = @client.get torrent_id

      if torrent?
        torrent.destroy()
        @client.remove torrent.infoHash

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
        callback e

      torrent = undefined
      timeout = setTimeout =>
        timeout = undefined
        @remove torrent

        log.warn "Metadata retrieval timed-out for [#{torrent?.infoHash ? 'null'}] Torrent"

        callback new Error('Metadata retrieval timed-out'), null
      , cfg.get 'torrent process timeout'

      @client.add torrent_id, {tmp: cfg.get 'sultanna path'}, (_torrent) =>
        torrent = _torrent

        if not timeout?
          log.warn "Metadata retrieval for Torrent [#{torrent?.infoHash or 'removed'}] occurred after timeout (ignoring)"
          @remove torrent
          return

        if not torrent?
          clearTimeout timeout
          return callback new Error('No metadata could be retrieved for torrent')

        torrent.discovery.tracker.scrape()
        torrent.discovery.tracker.once 'scrape', (data) =>
          if timeout?
            clearTimeout timeout
          else
            log.warn "Tracker scrapping for Torrent [#{torrent?.infoHash or 'removed'}] occurred after timeout (ignoring)"
            @remove torrent
            return

          torrent.seeders  = data.complete
          torrent.leechers = data.incomplete

          log.info "Metadata retrieved for Torrent [#{torrent.infoHash}]"
          callback null, torrent

    ###
      Find a Torrent's Metadata and return a Torrent Metadata Object, used for
      Search Indexing. Only {uploader}, {category} and {subcategory} cannot be
      set by this method and they'll reference an undefined uploader account
      and the "Others" category, with no sub-category.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @findMetadata = (torrent_id, callback) ->
      @get torrent_id, (err, torrent) =>
        if err or not torrent?
          @remove torrent
          return callback err ? new Error('Torrent metadata not retrieved')

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

        callback null, {
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

          seeders : torrent.seeders
          leechers: torrent.leechers
          indexed : new Date().getTime()
          updated : new Date().getTime()
          accessed: new Date().getTime()
        }, torrent.parsedTorrent

        @remove torrent

    ###
      Check if a given Torrent exists. Simply that.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @exists = (torrent_id, callback) ->
      @get torrent_id, (err, torrent) =>
        @remove torrent
        callback not err? and torrent?
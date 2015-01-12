module.exports = (cfg, log) ->
  string_decoder = new (require 'string_decoder').StringDecoder('utf8')
  parse_torrent = require 'parse-torrent'
  path = require 'path'

  ###
    Facilitates processing Torrents and their metadata.
  ###
  class torrent_helper
    ### WebTorrent Client Instance ###
    @client = new (require 'webtorrent')()

    ###
      Validates that a given String is a (possibly) valid InfoHash.

      @param hash (String) Hash to validate
      @returns (Boolean)
    ###
    @validHash = (hash) -> not not hash.match /[0-9a-z]{40}/i

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
        return undefined

      return path.join cfg.get('marianne path'),
        userhash.toUpperCase(),
        category.toUpperCase(),
        (subcategory or '').toUpperCase(),
        hash.toUpperCase()

    ###
      Find a Torrent in a Tracker, or via DHT, and return it in a callback.
      It's resource is not released nor removed from the list, that should be
      done manually unless an error occurred. Check the methods below this one
      for examples.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @get = (torrent_id, callback) ->
      timeout = setTimeout ->
        torrent.remove()
        timeout = undefined

        callback new Error('Metadata retrieval timed-out'), null
      , 10000

      @client.add torrent_id, {tmp: cfg.get 'sultanna path'}, (torrent) =>
        if not timeout?
          log.warn "Metadata retrieval for Torrent [#{torrent.infoHash}] occurred after timeout (ignoring)"
          return (@client.remove torrent.infoHash if torrent?.infoHash?)

        if not torrent?
          clearTimeout timeout
          log.info "No metadata found for Torrent [#{torrent.infoHash}]"
          return callback new Error('No metadata could be retrieved for torrent, apparently', null)

        torrent.discovery.tracker.once 'update', (data) ->
          if timeout?
            clearTimeout timeout
          else
            return (@client.remove torrent.infoHash if torrent?.infoHash?)

          torrent.seeders  = data.complete
          torrent.leechers = data.incomplete

          log.info "Metadata retrieved for Torrent [#{torrent.infoHash}]"
          callback null, torrent

    ###
      Find and Download a Torrent's README file. If available, it's contents
      are returned in the callback as a Readme Object.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @getReadme = (torrent_id, callback) ->
      @get torrent_id, (err, torrent) =>
        if err or not torrent?
          torrent?.remove()
          return callback err

        for file in torrent.files when file.name.match /readme(\.(md|txt|nfo))?$/i
          if file.length > cfg.get('max file size')
            log.info "File [#{file.name}] is too big to be a valid README"
            continue

          timeout = setTimeout ->
            timeout = undefined
            callback new Error('README download timed-out'), null
          , 20000

          return file.getBuffer (err, buffer) =>
            if timeout?
              clearTimeout timeout
            else
              return log.warn "README [#{file.name}] download from Torrent [#{torrent.infoHash}] occurred after timeout (ignoring)"

            if err
              log.warn "README [#{file.name}] download from Torrent [#{torrent.infoHash}] failed", err
              callback err
            else
              callback null, {
                str: string_decoder.write(buffer) + string_decoder.end()
                ext: file.name.match(/\.(md|txt|nfo)$/i)[0]
              }
              log.info "README [#{file.name}] download from Torrent [#{torrent.infoHash} successful"

            @client.remove torrent.infoHash

        # If this is reached, no README was found
        log.warn "README file in Torrent [#{torrent.infoHash}] not found"
        @client.remove torrent.infoHash if torrent?.infoHash?
        return callback new Error('No file is eligible to be README')

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
          @client.remove torrent.infoHash if torrent?.infoHash?
          return callback err or new Error('Torrent metadata not retrieved')

        callback null, {
          id: torrent.infoHash.toUpperCase()
          magnet: parse_torrent.toMagnetURI torrent.parsedTorrent
          uploader: undefined

          title: torrent.parsedTorrent.title
          description: ''

          category: 'other'
          subcategory: ''

          files_ix: (file.path for file in torrent.files).join(' ')
          files: (file.path for file in torrent.files)

          health:
            seeders : torrent.seeders
            leechers: torrent.leechers
            updated : new Date().getTime()
            accessed: new Date().getTime()
        }, torrent.parsedTorrent

        @client.remove torrent.infoHash

    ###
      Check if a given Torrent exists. Simply that.

      @param torrent_id (String|Object) A Parse-Torrent result, a Magnet URI or a Buffer of a *.torrent file
    ###
    @exists = (torrent_id, callback) ->
      @get torrent_id, (err, torrent) =>
        @client.remove torrent.infoHash if torrent?.infoHash?
        callback not err? and torrent?
module.exports = (torrent, cfg) ->
  string_decoder = new (require 'string_decoder').StringDecoder('utf8')
  path = require 'path'

  class torrent
    @client = new (require 'webtorrent')()

    @validHash = (hash) -> not not hash.match /[0-9a-z]{40}/i

    @getPath = @getLocalPath = (userhash, category, subcategory, hash) ->
      if not hash?
        hash = subcategory
        subcategory = null

      path.join cfg.get('marianne_dir'),
        userhash.toUpperCase(),
        category.toUpperCase(),
        (subcategory or '').toUpperCase(),
        hash.toUpperCase()

    @get = (torrent_id, callback) ->
      timeout = setTimeout ->
        torrent.remove()
        timeout = undefined

        callback new Error('Metadata retrieval timed-out'), null
      , 10000

      torrent = @client.add torrent_id, (torrent) ->
        if timeout?
          clearTimeout timeout
        else
          return

        torrent.seeders  = 0
        torrent.leechers = 0

        for wire in torrent.swarm.wires
          if wire.isSeeder
            torrent.seeders++
          else
            torrent.leechers++

        callback null, attach_health(torrent)

    @getReadme = (torrent_id, callback) ->
      @get torrent_id, (err, torrent) ->
        if err
          torrent.remove()
          return callback err

        for file in torrent.files when file.name.match /readme(\.(md|txt|nfo))?$/i
          continue if file.length > cfg.get('max file size')

          timeout = setTimeout ->
            timeout = undefined
            callback new Error('README download timed-out'), null
          , 20000

          return file.getBuffer (err, buffer) ->
            if timeout?
              clearTimeout timeout
            else
              return

            if err
              callback err
            else
              callback null, {
                str: string_decoder.write(buffer) + string_decoder.end()
                ext: file.name.match(/\.(md|txt|nfo)$/i)[0]
              }

            torrent.remove()

        # If this is reached, no README was found
        torrent.remove()
        return callback new Error('No file is elegible to be README')

    @getMetadata = (torrent_id, callback) ->
      @get torrent_id, (err, torrent) ->
        if err or not torrent?
          return callback err or new Error('Torrent metadata not retrieved')

        callback null, {
          id: torrent.parsedTorrent.infoHash.toUpperCase()
          magnet: undefined
          uploader: undefined

          title: torrent.parsedTorrent.title
          description: ''

          category: 'other'
          subcategory: ''

          files_ix: (file.path for file in torrent.files).join(' ')
          files: (file.path for file in torrent.files)

          health:
            seeders: torrent.seeders
            leechers: torrent.leechers
        }, torrent.parsedTorrent

        torrent.remove()

    @exists = (torrent_id, callback) ->
      @get torrent_id, (err, torrent) ->
        torrent.remove()
        callback not not err
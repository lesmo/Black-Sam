module.exports = (helpers) ->
  class helpers.torrent
    string_decoder = new (require 'string_decoder').StringDecoder('utf8')

    @client = new (require 'webtorrent')()

    @validHash = (hash) ->
      return not not hash.match /[0-9a-z]{40}/i

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

        callback null, attach_health(torrent)

    @getReadme = (torrent_id, callback) ->
      @get torrent_id, (err, torrent) ->
        if not err
          for file in torrent.files when file.name.match /readme(\.(md|txt|nfo))?$/i
            continue if file.length > 1024 * 1024 * 1024 #1mb

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
                callback err, null
              else
                callback null, {
                  str: string_decoder.write(buffer) + string_decoder.end()
                  ext: file.name.match(/\.(md|txt|nfo)$/i)[0]
                }

              torrent.remove()
        else
          # If we got to here, no file is a valid candidate
          torrent.remove()
          callback new Error('No file is eligible to be a README'), null

    @getMetadata = (torrent_id, callback) ->
      @get torrent_id, (err, torrent) ->
        if not err and torrent?
          attach_health torrent
          callback null, {
            id: torrent.parsedTorrent.infoHash.toUpperCase()
            magnet: undefined
            uploader: undefined

            title: torrent.parsedTorrent.title
            description: ''

            category: 'OTHER'
            subcategory: ''

            files_ix: (file.path for file in torrent.files).join(' ')
            files: (file.path for file in torrent.files)

            health:
              seeders : torrent.seeders
              leechers: torrent.leechers
          }, torrent.parsedTorrent
        else
          callback err, null

        torrent.remove()

    @exists = (torrent_id, callback) ->
      @get torrent_id, (err) ->
        callback not not err

    attach_health = (torrent) ->
      torrent.seeders  = 0
      torrent.leechers = 0

      for wire in torrent.swarm.wires
        if wire.isSeeder
          torrent.seeders++
        else
          torrent.leechers++

      return torrent
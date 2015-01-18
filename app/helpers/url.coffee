module.exports = (cfg) ->
  base32 = require 'base32'

  ###
    Facilitates calculation of URLs to different parts of BlackSam's controllers.
  ###
  class url
    @hash_mask = (hash) ->
      hash = new Buffer hash, 'hex'

      if cfg.enabled 'anti-seo'
        masked = new Buffer hash.length + 2
        key    = Math.floor Math.random() * parseInt('ffff', 16)

        masked.writeUInt16LE key, 0

        for i in [0...hash.length] by 2
          masked.writeUInt16LE hash.readUInt16LE(i) ^ masked.readUInt16LE(0), i + 2

        return base32.encode masked
      else
        return base32.encode hash

    @hash_unmask = (masked) ->
      masked = new Buffer base32.decode(masked), 'binary'

      if cfg.enabled 'anti-seo'
        hash = new Buffer masked.length - 2

        for i in [2...masked.length] by 2
          hash.writeUInt16LE masked.readUInt16LE(i) ^ masked.readUInt16LE(0), i - 2

        return hash.toString 'hex'
      else
        return masked.toString 'hex'

    ### URL to a Torrent page ###
    @torrent = (id) -> "/torrent/#{@hash_mask id}"
    ### URL to a Torrent Ajax page ###
    @torrent_ajax = (id) -> "/torrent/#{@hash_mask id}?aj=ax"
    ### URL to a Torrent file ###
    @torrent_file = (id) -> "/torrent/#{@hash_mask id}.torrent"

    @torrent_cat_icon = (category) -> ""

    ### URL to a Search page ###
    @search = (query, page) ->
      "/search?q=#{query}" +
        if page? > 1
          "&p=#{page}"
        else
          ''
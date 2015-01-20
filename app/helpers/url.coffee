module.exports = (helpers, cfg, log) ->
  base32 = require 'base32'

  ###
    Facilitates calculation of URLs to different parts of BlackSam's controllers.
  ###
  class url
    @hash_mask = (hash) ->
      hash = new Buffer hash, 'hex'

      if not cfg.enabled 'anti-seo'
        return base32.encode hash

      masked = new Buffer hash.length + 2
      now    = new Date()
      key    = now.getDate() * 24 * 60 + now.getMinutes()

      masked.writeUInt16LE key, 0

      for i in [0...hash.length] by 2
        masked.writeUInt16LE hash.readUInt16LE(i) ^ masked.readUInt16LE(0), i + 2

      return base32.encode masked

    @hash_unmask = (masked) ->
      masked = new Buffer base32.decode(masked), 'binary'

      if not cfg.enabled 'anti-seo'
        return masked.toString 'hex'

      hash = new Buffer masked.length - 2
      now  = new Date()
      now  = now.getDate() * 24 * 60 + now.getMinutes()
      key  = masked.readUInt16LE(0)

      return undefined if now < key      # Key can't be in the future
      return undefined if now > key + 60 # Key can't be more than 1 hour old

      for i in [2...masked.length] by 2
        hash.writeUInt16LE masked.readUInt16LE(i) ^ key, i - 2

      return hash.toString 'hex'

    ### URL to a Torrent page ###
    @torrent = (id) -> "/torrent/#{@hash_mask id}"
    ### URL to a Torrent Ajax page ###
    @torrent_ajax = (id) -> "/torrent/#{@hash_mask id}?aj=ax"
    ### URL to a Torrent file ###
    @torrent_file = (id) -> "/torrent/#{@hash_mask id}.torrent"

    @torrent_cat_icon = (category) -> "/img/cat/#{category}.png"

    ### URL to a Search page ###
    @search = (query, page) ->
      "/search?q=#{query}" +
        if page? > 1
          "&p=#{page}"
        else
          ''
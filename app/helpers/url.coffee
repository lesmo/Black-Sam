module.exports = () ->
  base32 = require 'base32'

  ###
    Facilitates calculation of URLs to different parts of BlackSam's controllers.
  ###
  class url
    @torrent_mask = (hash) ->
      hash   = new Buffer hash, 'hex'
      masked = new Buffer hash.length + 2
      key    = Math.floor Math.random() * parseInt('ffff', 16)

      masked.writeUInt16LE key, 0

      for i in [0...hash.length] by 2
        masked.writeUInt16LE hash.readUInt16LE(i) ^ masked.readUInt16LE(0), i + 2

      return masked.toString 'hex'

    @torrent_unmask = (masked) ->
      masked = new Buffer masked, 'hex'
      hash   = new Buffer masked.length - 2

      for i in [2...masked.length] by 2
        hash.writeUInt16LE masked.readUInt16LE(i) ^ masked.readUInt16LE(0), i - 2

      return hash.toString 'hex'

    ### URL to a Torrent page ###
    @torrent = (id) -> "/torrent/#{@torrent_mask(id)}"
    ### URL to a Torrent Ajax page ###
    @torrent_ajax = (id) -> "/torrent/#{@torrent_mask(id)}?aj=ax"
    ### URL to a Torrent file ###
    @torrent_file = (id) -> "/torrent/#{@torrent_mask(id)}.torrent"

    @torrent_cat_icon = (category) -> ""

    ### URL to a Search page ###
    @search = (query, page) ->
      "/search?q=#{query}" +
        if page? > 1
          "&p=#{page}"
        else
          ''
module.exports = () ->
  base32 = require 'base32'

  ###
    Facilitates calculation of URLs to different parts of BlackSam's controllers.
  ###
  class url
    @torrent_mask = (hash) ->
      binary_hash = base32.decode hash
      key = String.fromCharCode(Math.random().toString().slice(2, 5))

      result = String.fromCharCode(byte ^ key) for byte in binary_hash

      return base32.encode key + result.join('')

    @torrent_unmask = (hash) ->
      binary_hash = base32.decode hash
      key = hash[0]

      result = String.fromCharCode(byte ^ key) for byte in binary_hash.slice 1

      return base32.encode result.join('')

    ### URL to a Torrent page ###
    @torrent = (id) -> "/torrent/#{@torrent_mask(id)}"
    ### URL to a Torrent Ajax page ###
    @torrent_ajax = (id) -> "/torrent/#{@torrent_mask(id)}?aj=ax"
    ### URL to a Torrent file ###
    @torrent_file = (id) -> "/torrent/#{@torrent_mask(id)}.torrent"

    ### URL to a Search page ###
    @search = (query, page) ->
      "/search?q=#{query}" +
        if page? > 1
          "&p=#{page}"
        else
          ''
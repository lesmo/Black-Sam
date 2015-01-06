module.exports = (url) ->
  base32 = require 'base36'

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

    @torrent      = (id) -> "/torrent/#{@torrent_mask(id)}"
    @torrent_ajax = (id) -> "/torrent/#{@torrent_mask(id)}?aj=ax"
    @torrent_file = (id) -> "/torrent/#{@torrent_mask(id)}.torrent"

    @search = (query, page) -> "/search?q=#{query}&p=#{page}"
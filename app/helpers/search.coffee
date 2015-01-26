module.exports = (helpers, cfg, log) ->
  ###
    Keeps an instance of the Search Index object and allows easy access to
    commonly used Search-related functions.
  ###
  class SearchHelper
    ### Search Index ###
    @index = require('search-index')
      indexPath: cfg.get 'sherlock path'
      logLevel: 'error'

    ###
      Add a Torrent Metadata object or array of objects to add to the Search Index.

      @param torrent (Object|Array<Object>) Torrent Metadata.
      @param callback (Function) Exact same callback as if it were {si.add}
    ###
    @indexTorrent = (torrents, callback) ->
      if Array.isArray(torrents)
        torrent_count = "#{torrents.length} Torrents"
      else
        torrents = [torrents]
        torrent_count = "a Torrent"

      log.info "Adding #{torrent_count} to the Search Index ..."

      @index.add {
        batchName: 'helperBatch'
        filters: ['category', 'subcategory', 'uploader']
      }, torrents, (err) ->
        if err
          log.error "Error adding #{torrent_count} Torrents", err
        else
          log.info "Added #{torrent_count} to the Search Index"

        callback(err)
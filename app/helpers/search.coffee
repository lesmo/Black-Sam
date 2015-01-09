module.exports = () ->
  ###
    Keeps an instance of the Search Index object and allows easy access to
    commonly used Search-related functions.
  ###
  class search
    ### Search Index ###
    @index = require('search-index') {
      indexPath: app.get('sherlock_dir'),
      logLevel: 'error'
    }

    ###
      Add a Torrent Metadata object or array of objects to add to the Search Index.

      @param torrent (Object|Array<Object>) Torrent Metadata.
      @param callback (Function) Exact same callback as if it were {si.add}
    ###
    @indexTorrent = (torrent, callback) ->
      @index.add {
        batchName: 'helperBatch'
        filters: ['title', 'description', 'files_ix', 'files']
      }, if torrent.length > 0 then torrent else [torrent], callback
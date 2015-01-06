module.exports = (helpers) ->
  class helpers.search
    @index = require('search-index') {
      indexPath: app.get('sherlock_dir'),
      logLevel: 'error'
    }

    @indexTorrent = (torrent, callback) ->
      @index.add {
        batchName: 'helperBatch'
        filters: ['title', 'description', 'files_ix', 'files']
      }, if torrent.length > 0 then torrent else [torrent], callback
###
  This affects the behaviour of BlackSam's Search and Search Indexing.
###
module.exports = (cfg) ->
  # This is the frequency with which the Torrents database gets
  # checked for updates. This is not strict, timing starts when
  # the last Torrent has been checked. If the database is of
  # several thousands of Torrents, it could take several minutes
  # to check them all, and that time is not part of this setting.
  cfg.set 'indexer timespan', 1000 * 3600 # 1 hour

  # The number of results to show in Search pages.
  cfg.set 'search results per page', 20

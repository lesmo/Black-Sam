###
  These are advanced settings that heavily change how BlackSam behaves. Most
  of these are OK the way they currently are.

  Only change them if you know what you're doing.
###
module.exports = (cfg) ->
  # This is the logging level of BlackSam. Available levels are
  # 'info', 'warn' and 'error'. Comment this line to disable it.
  cfg.set 'log level', 'info'

  # This makes BlackSam output logs ONLY to the console. Useful
  # during development.
  cfg.disable 'log to file'

  # Un-comment this line if you want to disable Web Uploading.
  #cfg.disable 'web upload'

  # This enables or disables different Workers
  cfg.enable 'run indexer worker'
  cfg.enable 'run importer worker'

  # Max number of errors a Worker is allowed before stopping
  # further attempts at reviving it.
  cfg.set 'max worker fails', 100

  # This is the frequency with which each Worker is run after it
  # finishes it's job. This is not strict, timing starts when the
  # Worker has finished it's last job, which in some cases could
  # be several minutes.
  cfg.set 'worker timespan', 1000 * 3600 # 1 hour

  # If you want to set a timespan for a specific Worker, you can
  # set it like the Cleanup Worker's timespan is set below. Note
  # that Cleanup Worker creates a file called "cleanup.json"
  # that keeps the last date the cleanup was ran, so it's not
  # lost if BlackSam is killed.
  cfg.set 'worker cleanup timespan', 1000 * 3600 * 24 * 3 #3 days

  # Comment this line to kill BlackSam when the number above is
  # reached by a Worker. It's recommended to disable this on
  # a production server.
  cfg.enable 'die on max worker fails'

  # Whether to rename or delete conflicting Torrents during
  # indexing. A conflicting Torrent is one which differs in
  # uploader or categories from the filesystem and the Index.
  cfg.set 'torrent conflict solution', 'rename'

  # Extension used when above is 'rename'.
  cfg.set 'torrent conflict extension', 'bak'

  # This determines how BlackSam will process download of
  # metadata and indexing. There's two options:
  #   parallel - Run the processing of the whole batch at the
  #              same time. Provides faster indexing, but may
  #              starve bandwidth, ram or processor in small
  #              servers.
  #   series   - Run the processing of the batch one item at
  #              a time. It could be slow, mostly for
  #              just-setup install. Works best for dedicated
  #              infrastructure.
  cfg.set 'torrent index worker method', 'series'

  # Items per processing batch
  cfg.set 'torrent index worker batch', 20

  # Timeout for operations on Torrents, like retrieving metadata
  # or README files. Affects part of the Web behaviour.
  cfg.set 'torrent process timeout', 1000 * 30

  # Time threshold after which a Torrent is checked for seed and
  # leech counts. This is the amount of time since last update
  # that must pass before BlackSam finds new seed and leech counts.
  # This only happens when the Torrent is "accessed" after this
  # period of time to save resources on non-popular Torrents.
  #
  # The format can be whatever Sugar.js accepts as valid argument
  # for the "advance" method: http://sugarjs.com/api/Date/advance
  cfg.set 'torrent update time threshold', hour: 1
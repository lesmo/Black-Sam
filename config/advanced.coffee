###
  These are advenced settings that heavily change how BlackSam behaves. Most
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

  # Comment this line if you want to disable the Indexer Worker.
  # This is not recommended. Honestly, I don't know why I put it
  # there. Just don't touch it.
  cfg.enable 'run indexer worker'

  # Max number of errors a Worker is allowed before stopping
  # further attempts at reviving it.
  cfg.set 'max worker fails', 100

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
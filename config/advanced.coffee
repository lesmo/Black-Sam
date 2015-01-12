###
  These are advenced settings that heavily change how BlackSam behaves. Most
  of these are OK the way they currently are.

  Only change them if you know what you're doing.
###
module.exports = (cfg) ->
  # Un-comment this line if you want to disable Web Uploading.
  #cfg.disable 'web upload'

  # Un-comment this line if you want to disable the Indexer Worker.
  # This is not recommended. Honestly, I don't know why I put it
  # there. Just don't touch it.
  #cfg.disable 'run indexer worker'

  # Max number of errors a Worker is allowed before stopping
  # further attempts at reviving it.
  cfg.set 'max worker fails', 100

  # Whether to rename or delete conflicting Torrents during
  # indexing. A conflicting Torrent is one which differs in
  # uploader or categories from the filesystem and the Index.
  cfg.set 'torrent conflict solution', 'delete'

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
  cfg.set 'torrent index worker batch', 10
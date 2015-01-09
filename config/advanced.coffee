###
  These are advenced settings that heavily change how BlackSam behaves. Most
  of these are OK the way they currently are.

  Only change them if you know what you're doing.
###
module.exports = (cfg) ->
  # Max number of errors a Worker is allowed before stopping
  # further attempts at reviving it
  cfg.set 'max worker fails', 100
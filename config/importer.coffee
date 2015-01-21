###
  This changes the behaviour of the Importer Worker, responsible for scanning
  and moving Torrent fiels and Magnet Links from inside the Sultanna Folder.

  The Importer Worker only moves files from the [sultanna/import] directory
  into a valid user-folder in [marianne] folder. This is useful for
###
module.exports = (cfg) ->
  # This determines the amount of simultaneous Torrents
  # that will be moved, renamed and searched on Trackers
  # and the DHT for metadata of Magnet Links at the same
  # time. Higher numbers might make the import process
  # faster, but could starve bandwidth or disk I/O.
  cfg.set 'importer torrents per batch', 20

  # During import, BlackSam can generate a random-userdir
  # so all Torrents imported remain truly anonymous. This
  # will be the number of Torrents BlackSam will store per
  # random-userdir. Set to 0 to disable this.
  cfg.set 'importer random userdir torrents', 20

  # After Torrents have finished imporitng, BlackSam can
  # lock the randomly generated user so no new Torrents
  # can be added nor synced. It's highly discouraged to
  # disable this. It should only be used for debugging.
  cfg.enable 'importer lock random userdir'

  # If above is disable, this is the userdir to store all
  # imported Torrents into. It must be a valid User Hash,
  # and the directory doesn't necessarily have to exist
  # already.
  cfg.set 'importer userdir', '1-C92E130010D346C39984BAF79EC6C534A5ABF6C8'
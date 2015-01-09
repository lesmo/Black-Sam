###
  Go through all directories in [marianne] and retrieve available Torrents, and
  make sure they're properly Indexed.

  This Worker does not update seed/leech count.
###

module.exports = (helpers) ->
  parse_torrent = require 'parse-torrent'
  async = require 'async'
  path = require 'path'
  fs = require 'fs'

  marianne = helpers.config.get 'marianne path'

  find_file_meta = (filepath, userhash) -> (done) ->
    return done() if not userhash?

    info_hash = path.basename(filepath).match(/(.*)\..*/i)[1].toUpperCase()
    parsed_torrent = parse_torrent fs.readFileSync filepath

    category = (path.basename path.dirname filepath).toLowerCase()
    category = 'others' if category is userhash

    subcategory = (path.basename path.dirname path.dirname filepath).toLowerCase()
    subcategory = '' if subcategory is userhash

    if helpers.torrent.validHash(info_hash) and info_hash is parsed_torrent.infoHash
      helpers.search.index.get infohash, (err, _torrent_meta) ->
        if not err? and _torrent_meta?
          userhash    = _torrent_meta.uploader if _torrent_meta.uploader isnt userhash
          category    = _torrent_meta.category if _torrent_meta.category isnt category
          subcategory = _torrent_meta.subcategory if _torrent_meta.subcategory isnt subcategory

        find_torrent_meta()
    else
      find_torrent_meta()

    find_torrent_meta = () ->
      if helpers.config.get('categories')[category]?
        if subcategory.length > 0
          if helpers.config.get('categories')[category].indexOf(subcategory) < 0
            return done() # Subcategory is ignored (delete torrent?)
      else
        return done() # Category is ignored (delete torrent?)

      helpers.torrent.findMetadata parsed_torrent, (err, torrent_meta) ->
        if torrent_meta?
          torrent_meta.uploader    = userhash
          torrent_meta.category    = category
          torrent_meta.subcategory = subcategory

          # TODO: Move/rename Torrent file to reflect accurate uploader, categories and infohash

          done null, torrent_meta
        else
          # TODO: Delete torrent?
          done()

  get_files = (dirpath, files) ->
    for item in fs.readdirSync dirpath
      stat = fs.lstatSync(item)

      if stat.isDirectory()
        get_files "#{dirpath}/#{item}", files
      else if stat.isFile() and item.match /\.torrent$/
        files.push "#{dirpath}/#{item}"

  return (next) ->
    index_batch = []

    for user_dir in fs.readdirSync marianne when fs.lstatSync("#{marianne}/#{user_dir}").isDirectory()
      continue if not helpers.user.validHash user_dir

      files = []
      get_files "#{marianne}/#{user_dir}", files

      for file in files
        index_batch.push find_file_meta(file, user_dir)

    async.parallel index_batch, (err, torrents) ->
      helpers.search.indexTorrent t for t in torrents when t?, ->
        setTimeout next, app.get('indexer timespan')
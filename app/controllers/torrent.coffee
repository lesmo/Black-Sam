module.exports = (helpers, cfg, log) ->
  parse_torrent = require 'parse-torrent'
  async         = require 'async'
  multer        = require 'multer'
  fs            = require 'fs-extra'

  class TorrentController
    @routes = (router) ->
      router.use multer {
        dest: cfg.get 'sultanna_dir',
        limits:
          files: 2
          fileSize: cfg.get 'max file size'
      }

      router.param 'id', (req, res, next, id) ->
        if not id?.length > 19
          id = undefined
          return next()

        id = helpers.url.hash_unmask id

        if id?
          req.params.id = id
          next()
        else
          res.redirect '/'

      router.get '/new', (req, res) ->
        if req.user.loggedIn
          res.render 'torrent/upload'
        else
          res.redirect '/account/new'

      router.post '/new', (req, res) ->
        return res.redirect '/account/new' if not req.user.loggedIn
        return res.render 'torrent/upload' if not req.body?

        if not req.body.torrent_magnet?.length > 20 and not req.files?.torrent_file?
          helpers.errors.addFatal 'blacksam.upload.empty'

        category = req.body.torrent_category?.toLowerCase().split('#', 2)

        if category?.length is 2
          subcategory = category[1]
        else
          subcategory = 'other'

        category = category?[0]

        if not cfg.get('categories')[category]?
          res.errors.addValidation 'torrent_category'
        else if not cfg.get('categories')[category].find(subcategory)?
          res.errors.addValidation 'torrent_category', 'Invalid subcategory ' + subcategory

        if req.files?.torrent_file?
          torrent = parse_torrent fs.readFileSync(req.files.torrent_file.path)
        else if req.body.torrent_magnet?.length > 20
          torrent = parse_torrent req.body.torrent_magnet
        else
          torrent = 0

        if not torrent?
          res.errors.addFatal 'blacksam.upload.invalid'

        if res.errors.fatal.length is 0 and res.errors.validation.length is 0
          torrent_upload req, res
            , torrent
            , category
            , subcategory
            , req.body.torrent_description
        else
          res.render 'torrent/upload'

      router.get '/:id.torrent', (req, res, next) ->
        torrent_download req, res, next, req.params.id.toUpperCase()
      router.get '/:id', (req, res, next) ->
        torrent_page req, res, next, req.params.id.toUpperCase()

    torrent_page = (req, res, next, torrent_id) ->
      if not torrent_id?
        return next()

      helpers.search.index.get torrent_id, (err, torrent) ->
        if err or not torrent?
          log.warn "[#{torrent_id}] does not exist in Search Index"
          return next()

        torrent = JSON.parse torrent

        async.parallel [
          (callback) ->
            fs.stat "#{helpers.torrent.getPath torrent}.md", (err, res) ->
              callback null, res
          (callback) ->
            fs.stat "#{helpers.torrent.getPath torrent}.torrent", callback
        ], (err, files) ->
          if err or not files[1]?.isFile() or files[1].size > cfg.get('max file size')
            log.warn err?.message ? "[#{torrent_id}.torrent] is not a file, or too large. Deleting from Search Index..."
            helpers.search.index.del torrent_id, next
          else
            if files[0]?.size < cfg.get('max file size')
              torrent.description = fs.readFileSync("#{helpers.torrent.getPath torrent}.md").toString()

            res.render 'torrent/torrent', torrent: torrent

    torrent_download = (req, res, next, torrent_id) ->
      return next() if not torrent_id?

      helpers.search.index.get torrent_id, (err, torrent) ->
        if err or not torrent?
          log.warn "[#{torrent_id}] does not exist in Search Index"
          return next()

        torrent = JSON.parse torrent
        torrent_store_path = helpers.torrent.getLocalPath torrent

        fs.stat "#{torrent_store_path}.torrent", (err, file) ->
          if err or not file.isFile() or file.size > cfg.get('max file size')
            helpers.search.index.del torrent.id, (err) ->
              log.warn err or "[#{torrent_id}.torrent] is not a file, or too large. Deleted from Search Index."
              next()
          else
            res.download "#{torrent_store_path}.torrent", "#{torrent.title}.torrent"

    torrent_upload = (req, res, torrent, category, subcategory, description) ->
      torrent_store_path = helpers.torrent.getLocalPath req.session.userhash
        , category
        , subcategory
        , torrent.infoHash

      async.waterfall [
        # Determine if Torrent already exists
        (next_step) ->
          fs.exists "#{torrent_store_path}.torrent", (exists) ->
            if exists
              next_step res.errors.addFatal 'blacksam.upload.exists'
            else
              next_step()

        # Find Torrent metadata
        (next_step) ->
          helpers.torrent.findMetadata torrent, next_step

        # Parse to Torrent File Buffer and Indexable object
        (metadata, parsed_torrent, next_step) ->
          try
            torrent_buffer = parse_torrent.toTorrentFile parsed_torrent
            metadata.magnet = parse_torrent.toMagnetURI parsed_torrent

            if description?.length > 8
              metadata.description = description.parameterize().spacify()

            next_step null, metadata, torrent_buffer, description
          catch e
            next_step e

        # Write Torrent File and Description File
        (metadata, torrent_buffer, description, next_step) ->
          async.parallel [
            (done) ->
              fs.outputFile "#{torrent_store_path}.torrent", torrent_buffer, done
            (done) ->
              if description?.length > 8
                fs.outputFile "#{torrent_store_path}.md", description, done
              else
                done()
          ], (err) ->
            if err
              next_step res.errors.addFatal('blacksam.upload.failed')
            else
              next_step null, metadata

        # Index the Torrent
        (metadata, next_step) ->
          helpers.search.indexTorrent metadata, (err) ->
            if err
              next_step res.errors.addFatal('blacksam.upload.index_failed', error: err)
            else
              next_step null, metadata
      ], (err, metadata) ->
        if err?
          if not err.type?.match /^blacksam\./
            res.errors.addFatal 'blacksam.upload.invalid', error: err

          res.render 'torrent/upload'
        else
          res.redirect helpers.url.torrent(metadata.infoHash)
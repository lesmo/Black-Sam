module.exports = (helpers, log) ->
  parse_torrent = require 'parse-torrent'
  async = require 'async'
  multer = require 'multer'
  fs = require 'fs-extra'

  class TorrentController
    @routes = (router) ->
      router.use multer {
        dest: helpers.config.get 'sultanna_dir',
        limits:
          files: 2
          fileSize: helpers.config.get 'max file size'
      }

      router.param 'id', (req, res, next, id) ->
        if not id?.length > 19
          id = undefined
          return next()

        id = helpers.url.torrent_unmask id

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

        category = category[0]

        if not helpers.config.get('categories')?[category]?
          helpers.errors.addValidation field: 'torrent_category'
        else if subcategory? and not helpers.config.get('categories')?[category]?.has?(subcategory)
          helpers.errors.addValidation field: 'torrent_category'

        if req.body.torrent_title?.length < 5
          helpers.errors.addValidation field: 'torrent_title'

        if req.files?.torrent_file?
          torrent = parse_torrent fs.readFileSync(req.files.torrent_file.path)
        else if req.body.torrent_magnet?.length > 20
          torrent = parse_torrent req.body.torrent_magnet
        else
          torrent = 0

        if not torrent?
          helpers.errors.addFatal 'blacksam.upload.invalid'

        if res.errors.fatal.length is 0 and res.errors.validation.length is 0
          torrent_upload req, res
            , torrent
            , req.body.torrent_title
            , category
            , subcategory
            , req.body.torrent_description
        else
          res.render 'torrent/upload'

      router.get '/new/get-readme', (req, res) ->
        if req.query?.hash? and helpers.torrent.validHash(req.query.hash)
          if req.user.loggedIn
            torrent_readme req, res, req.query.hash
          else
            res.status(401).json {}
        else
          res.status(400).json {}

      router.get '/:id.torrent', (req, res, next) ->
        torrent_download req, res, next, req.params.id.toUpperCase()
      router.get '/:id', (req, res, next) ->
        torrent req, res, next, req.params.id.toUpperCase()

    torrent = (req, res, next, torrent_id) ->
      return next() if not torrent_id?

      helpers.search.index.get torrent_id, (err, torrent) ->
        if err or not torrent
          log.warn "[#{torrent_id}] does not exist in Search Index"
          return next()

        async.parallel [
          (callback) ->
            fs.stat "#{helpers.torrent.getPath torrent}.md", (err, res) ->
              callback null, res
          (callback) ->
            fs.stat "#{helpers.torrent.getPath torrent}.torrent", callback
        ], (err, files) ->
          if err or not files[1]? or not files[1].isFile() or files[1].size > helpers.config.get('max file size')
            helpers.search.index.del torrent_id, (err) ->
              log.warn err or "[#{torrent_id}.torrent] is not a file, or too large. Deleted from Search Index."
              next()
          else
            if files[0]?.size < helpers.config.get('max file size')
              torrent.description = fs.readFileSync("#{helpers.torrent.getPath torrent}.md").toString()

            res.render 'torrent/torrent', torrent: torrent

    torrent_download = (req, res, next, torrent_id) ->
      helpers.search.index.get torrent_id, (err, torrent) ->
        if not torrent
          log.warn "[#{torrent_id}] does not exist in Search Index"
          next()
        else
          torrent_store_path = helpers.torrent.getLocalPath req.session.userhash
            , torrent.category
            , torrent.subcategory
            , torrent_id

          fs.stat "#{torrent_store_path}.torrent", (err, file) ->
            if err or not file.isFile() or file.size > helpers.config.get('max file size')
              helpers.search.index.del torrent.id, (err) ->
                log.warn err or "[#{torrent_id}.torrent] is not a file, or too large. Deleted from Search Index."
                next()
            else
              res.download "#{torrent_store_path}.torrent"

    torrent_readme = (req, res, hash) ->
      helpers.torrent.getReadme hash, (err, readme) ->
        if err
          res.status(404).json {}
        else
          res.status(200).json readme

    torrent_upload = (req, res, torrent, title, category, subcategory, description) ->
      torrent_store_path = helpers.torrent.getLocalPath req.session.userhash
        , category
        , subcategory
        , torrent.infoHash

      if fs.existsSync "#{torrent_store_path}.torrent"
        helpers.errors.addFatal 'blacksam.upload.exists'
        return res.render 'torrent/validation_failed'

      helpers.torrent.findMetadata torrent, (err, metadata, parsed_torrent) ->
        if err
          helpers.errors.addFatal 'blacksam.upload.invalid'
          return res.render 'torrent/validation_failed'

        parsed_torrent.title = title

        torrent_buffer = parse_torrent.toTorrentFile parsed_torrent
        metadata.magnet = parse_torrent.toMagnetURI parsed_torrent

        fs.outputFile "#{torrent_store_path}.torrent", torrent_buffer, (err) ->
          if err
            helpers.errors.addFatal 'blacksam.upload.failed', error: err
            return res.render 'torrent/validation_failed'

          if description?.length > 8
            fs.outputFile "#{torrent_store_path}.md", description
            metadata.description = description.parameterize().spacify()

          helpers.search.indexTorrent metadata, (err) ->
            if err
              helpers.errors.addFatal 'blacksam.upload.index_failed', error: err
              res.render 'torrent/validation_failed'
            else
              res.redirect helpers.url.torrent(torrent.id)
module.exports = (torrent, helpers) ->
  parse_torrent = require 'parse-torrent'
  fs = require 'fs-extra'
  async  = require 'async'
  log = require 'winston'

  class torrent
    @routes = (router) ->
      router.use require('multer') {
        dest: app.get('sultanna_dir'),
        limits:
          files: 2
          fileSize: helpers.config.get 'max file size'
      }

      router.param 'id', (req, res, next, id) ->
        req.params.id = helpers.torrent_unmask id if id?
        next()

      router.get '/new', (req, res) ->
        if req.user.loggedIn
          res.render 'torrent/upload'
        else
          res.redirect '/account/new'

      router.post '/new', (req, res) ->
        return res.redirect '/account/new' if not req.user.loggedIn
        return res.render 'torrent/upload' if not req.body?

        e = {}

        if not req.body.torrent_magnet? and not req.files?.torrent_file?
          e.noSourceSelected = true

        category = req.body.torrent_category?.toLowerCase()
        subcategory = req.body.torrent_subcategory?.toLowerCase()

        if not helpers.config.get('categories')?[category]?
          e.noCategorySelectd = true

        if req.body.torrent_title?.length < 5
          e.titleTooShort = true

        torrent = parse_torrent if req.files.torrent_file?
          fs.readFileSync req.files.torrent_file.path
        else
          req.body.torrent_magnet

        if not torrent?
          e.invalidTorrent = true

        if e is {}
          torrent_upload req, res,
            torrent,
            req.body.torrent_title,
            category,
            subcategory,
            req.body.torrent_description
        else
          res.render 'torrent/upload', errors: e

      router.get '/new/get-readme', (req, res) ->
        if req.query?.hash? and controllers.helpers.torrent.validHash req.query.hash
          if req.user.loggedIn
            torrent_readme(req, res, req.query.hash)
          else
            res.status(401).send {}
        else
          res.status(400).send {}

      router.get '/:id.torrent', (req, res, next) ->
        torrent_download req, res, next, req.params.id.toUpperCase()
      router.get '/:id', (req, res, next) ->
        torrent req, res, next, req.params.id.toUpperCase()

    torrent = (req, res, next, torrent_id) ->
      search.index.get torrent_id, (err, torrent) ->
        if not torrent
          log.warn "[#{torrent_id}] does not exist in Search Index"
          return next()

        async.parallel [
          (callback) ->
            fs.stat "#{torrent.localUri}.md", (err, res) ->
              callback null, res
          (callback) ->
            fs.stat "#{torrent.localUri}.torrent", callback
        ], (err, files) ->
          if err or not files[1]? or not files[1].isFile() or files[1].size > max_size
            search.index.del torrent.id, (err) ->
              log.warn err or "[#{torrent_id}.torrent] is not a file, or too large. Deleted from Search Index"

              next()
          else
            if files[0]?.size < max_size
              torrent.description = fs.readFileSync("#{torrent.localUri}.md").toString()

            res.render 'torrent', torrent: torrent

    torrent_download = (req, res, next, torrent_id) ->
      helpers.search.index.get torrent_id, (err, torrent) ->
        if not torrent
          log.warn "[#{torrent_id}] does not exist in Search Index"
          next()
        else
          torrent_store_path = "#{controllers.app.get('marianne_dir')}/#{req.session.userhash}/#{torrent.infoHash.toUpperCase()}"

          fs.stat "#{torrent_store_path}.torrent", (err, file) ->
            if err or not file.isFile() or file.size > max_size
              helpers.search.index.del torrent.id, (err) ->
                log.warn err or "[#{torrent_id}.torrent] is not a file, or too large. Deleted from Search Index"

                next()
            else
              res.download "#{torrent_store_path}.torrent"

    torrent_readme = (req, res, hash) ->
      helpers.torrent.getReadme hash, (err, readme) ->
        if err
          res.status(404).send {}
        else
          res.status(200).json readme

    torrent_upload = (req, res, torrent, title, category, subcategory, description) ->
      torrent_store_path = helpers.torrent.getLocalPath(
        req.session.userhash,
        category,
        subcategory,
        torrent.infoHash
      )

      if fs.existsSync "#{torrent_store_path}.torrent"
        return res.render 'torrent/validation_failed', errors: {alreadyExists: true}

      helpers.torrent.getMetadata torrent, (err, metadata, parsed_torrent) ->
        if err
          return res.render 'torrent/validation_failed', errors: {invalid: true}

        torrent_buffer = parse_torrent.toTorrentFile parsed_torrent
        metadata.magnet = parse_torrent.toMagnetURI parsed_torrent

        fs.outputFile "#{torrent_store_path}.torrent", torrent_buffer, (err) ->
          if err
            return res.render 'torrent/validation_failed', errors: {unexpectedError: err}

          if description?.length > 8
            fs.outputFile "#{torrent_store_path}.md", description
            metadata.description = description

          helpers.search.indexTorrent metadata
          res.render 'torrent/upload_successful'
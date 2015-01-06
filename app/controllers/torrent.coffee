module.exports = (controllers) ->
  class controllers.torrent
    parse_torrent = require 'parse-torrent'
    fs = require 'fs-extra'
    async  = require 'async'
    log = require 'winston'

    helpers = controllers.helpers

    max_size = 1024 * 1024 # 1mb

    @routes = (router) ->
      router.use require('multer') {
        dest: app.get('sultanna_dir'),
        limits:
          files: 2
          fileSize: 1024 * 1024 * 1024 #1mb
      }

      router.param 'id', (req, res, next, id) ->
        if id?
          req.params.id = helpers.torrent_unmask id

        next()

      router.get '/new', (req, res) ->
        if req.user.loggedIn
          res.render 'torrent/upload'
        else
          res.redirect '/account/new'

      router.post '/new', (req, res) ->
        if req.user.loggedIn
          torrent_upload(req, res)
        else
          res.redirect '/account/new'

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
              if err
                log.warn err
              else
                log.warn "[#{torrent_id}.torrent] is not a file, or too large. Deleted from Search Index"

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
                if err
                  log.warn err
                else
                  log.warn "[#{torrent_id}.torrent] is not a file, or too large. Deleted from Search Index"

                next()
            else
              res.download "#{torrent_store_path}.torrent"

    torrent_readme = (req, res, hash) ->
      helpers.torrent.getReadme hash, (err, readme) ->
        if err
          res.status(404).send {}
        else
          res.status(200).json readme

    torrent_upload = (req, res) ->
      if not req.body?
        return res.render 'torrent/upload'

      e = {}

      if not req.body.torrent_magnet? and not req.files?.torrent_file?
        e.noSourceSelected = true
      # TODO: Validate category
      if req.body.torrent_title?.length < 5
        e.titleTooShort = true

      if not e is {}
        return res.render 'torrent/upload', errors: e

      torrent = parse_torrent if req.files.torrent_file?
        fs.readFileSync req.files.torrent_file.path
      else
        req.body.torrent_magnet

      torrent_store_path = "#{controllers.app.get('marianne_dir')}/#{req.session.userhash}/#{torrent.infoHash.toUpperCase()}"

      if not torrent?
        return res.render 'torrent/validation_failed', errors: {invalid: true}
      if fs.existsSync "#{torrent_store_path}.torrent"
        return res.render 'torrent/validation_failed', errors: {alreadyExists: true}

      helpers.torrent.getMetadata torrent, (err, metadata, parsed_torrent) ->
        if err
          res.render 'torrent/validation_failed', errors: {invalid: true}
        else
          torrent_buffer = parse_torrent.toTorrentFile parsed_torrent
          metadata.magnet = parse_torrent.toMagnetURI parsed_torrent

          fs.outputFile "#{torrent_store_path}.torrent", torrent_buffer, (err) ->
            if err
              res.render 'torrent/validation_failed', errors: {unexpectedError: err}
            if req.body.torrent_description?.length > 8
              fs.outputFile "#{torrent_store_path}.md", req.body.torrent_description
              metadata.description = req.body.torrent_description

            helpers.search.addTorrent metadata
            res.render 'torrent/upload_successful'
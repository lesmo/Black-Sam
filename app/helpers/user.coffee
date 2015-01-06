module.exports = (helpers, cfg) ->
  class helpers.user
    crypto = require('cryptojs').Crypto
    fs = require 'fs-extra'
    q = require 'q'

    @middleware = (err, req, res, next) ->
      res.locals.user = req.user =
        loggedIn: @exists(req.session.userhash)

      next()

    @getHash = (username, password) ->
      hash = username + password
      hash = crypto.SHA512(hash).toString()
      hash = crypto.SHA256(hash).toString()
      hash = crypto.RIPEMD160(hash).toString()

      return hash

    @validHash = (hash) ->
      return hash.match /^[0-9a-f]{40}$/i

    @getPath = @getLocalPath = (hash) ->
      return "#{cfg.get('marianne dir')}/1-#{hash.toUpperCase()}"

    @exists = (hash) ->
      return fs.existsSync this.getPath(hash)

    @create = (username, password) ->
      deferred = q.defer()

      if password
        userhash = @getHash(username, password)
      else
        userhash = username.toUpperCase()

        if not @validHash(userhash)
          deferred.reject()
          return deferred.promise

      if @exists(userhash)
        deferred.reject new Error('User Name and Password combination already exist')
      else
        fs.mkdirs @getPath(userhash), (err) ->
          if err
            deferred.reject err
          else
            deferred.resolve(userhash)

      return deferred.promise
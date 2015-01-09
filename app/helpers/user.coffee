module.exports = (cfg) ->
  crypto = require('cryptojs').Crypto
  fs = require 'fs-extra'
  q = require 'q'

  ###
    Facilitates the interaction with User Accounts, their folders, hashing and validations.
  ###
  class user
    ###
      The Middleware associates the User object to the {req} object, and
      the templating engine {user}.
    ###
    @middleware = (err, req, res, next) ->
      res.locals.user = req.user =
        loggedIn: @exists(req.session.userhash)

      next()

    ###
      Calculate a User Hash for a given {username} and {password}.
    ###
    @getHash = (username, password) ->
      hash = username + password
      hash = crypto.SHA512(hash).toString()
      hash = crypto.SHA256(hash).toString()
      hash = crypto.RIPEMD160(hash).toString()

      return hash

    ###
      Checks if a given {hash} could be a valid User Hash.
    ###
    @validHash = (hash) ->
      regex_match = hash.match /^(1\-)?([0-9a-f]{40})$/i

      if regex_match?.length is 3
        return regex_match[2].toUpperCase()
      else
        return undefined

    ###
      Calculates the path a User Hash would be located at.
    ###
    @getPath = @getLocalPath = (hash) ->
      hash = @validHash hash

      if hash
        return "#{cfg.get('marianne dir')}/#{@validHash hash}"
      else
        return undefined

    ###
      Checks if a User Folder exists for the given User Hash.
    ###
    @exists = (hash) ->
      path = @getPath hash

      if path
        return fs.existsSync path
      else
        return false

    ###
      Creates a new User Account with the given User Hash or User Name and
      Password combination.
    ###
    @create = (username, password) ->
      deferred = q.defer()

      if password
        userhash = @getHash(username, password)
      else
        userhash = username.toUpperCase()

        if not @validHash userhash
          deferred.reject()
          return deferred.promise

      if @exists userhash
        deferred.reject new Error('User Name and Password combination already exist')
      else
        fs.mkdirs @getPath(userhash), (err) ->
          if err
            deferred.reject err
          else
            deferred.resolve(userhash)

      return deferred.promise
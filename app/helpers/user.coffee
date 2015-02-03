module.exports = (helpers, cfg, log) ->
  cfg =
    marianne_path: cfg.get 'marianne path'

  ###
    Facilitates the interaction with User Accounts, their folders, hashing and validations.
  ###
  class UserHelper
    ###
      An alias for {helpers.crypto.user.getHash}
    ###
    @getHash = helpers.crypto.user.getHash

    ###
      The Middleware associates the User object to the {req} object, and
      the templating engine {user}.
    ###
    @middleware = (req, res, next) =>
      res.locals.user = req.user =
        loggedIn: @exists(req.session.userhash)

      next()

    ###
      Checks if a given {hash} could be a valid User Hash.
    ###
    @validHash = (hash) ->
      if not hash?
        return undefined

      regex_match = hash.match /^(1\-)?([0-9A-F]{40})$/i

      if regex_match?
        return "1-#{regex_match[2].toUpperCase()}"
      else
        return undefined

    ###
      Calculates the path a User Hash would be located at.
    ###
    @getPath = @getLocalPath = (hash) ->
      hash = @validHash hash

      if hash?
        return "#{cfg.marianne_path}/#{@validHash hash}"
      else
        return undefined

    ###
      Checks if a User Folder exists for the given User Hash.
    ###
    @exists = (hash) ->
      path = @getPath hash

      if path?
        return helpers.fs.existsSync path
      else
        return false

    ###
      Creates a new User Account with the given User Hash or User Name and
      Password combination.
    ###
    @create = (credentials..., callback) ->
      if credentials.length < 1 or credentials.length > 2
        return async.nextTick ->
          callback new Error('blacksam.generic.invalidArguments')

      if credentials.length is 1
        userhash = @getHash credentials[0], credentials[1]
      else
        userhash = @validHash credentials[0]

      if not userhash?
        return async.nextTick ->
          callback new Error('blacksam.generic.invalidArguments')

      if @exists userhash
        callback new Error('blacksam.user.create.exists')
      else
        helpers.fs.mkdirp @getPath(userhash), (err) ->
          if err
            log.error "User Folder [#{userhash}] creation failed", err
          else
            log.info "User Folder [#{userhash}] created"

          callback err, userhash

    @getDisplayName = (userhash) ->
      userpath = @getLocalPath userhash

      if not userpath?
        return 'invalid'

      for file in helpers.fs.readdirSync userpath
        display_name = file.match(/^user\.(.+)\.json$/i)?[1]
        return display_name if display_name?

      # If we got to here, no user json file was found
      return 'anonymous'

    @getMetadata = (userhash) ->
      userpath = @getLocalPath userhash

      if not userpath?
        return displayName: 'invalid'

      userhash  = @validHash(userhash).from(2)

      for file in helpers.helpers.fs.readdirSync(userpath) when display_name = file.match(/^user\.(.+)\.json$/i)
        userjson = helpers.helpers.fs.readJSONSync "#{userpath}/#{file}"

        if not userjson?
          continue

        userjson.displayName = display_name[1]

        if helpers.crypto.user.validJson userhash, userjson
          delete userjson.seedhash
          return userjson
        else
          return displayName: 'invalid'

      # If we got to here, no user json file was found
      return displayName: 'anonymous'
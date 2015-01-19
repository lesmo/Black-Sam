module.exports = (helpers, cfg, log) ->
  fs = require 'fs-extra'
  q = 'q'

  ###
    Facilitates the interaction with User Accounts, their folders, hashing and validations.
  ###
  class user
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
      return undefined if not hash?

      regex_match = hash.match /^(1\-)?([0-9A-F]{40})$/i

      if regex_match?.length is 3
        return "1-#{regex_match[2]}"
      else
        return undefined

    ###
      Calculates the path a User Hash would be located at.
    ###
    @getPath = @getLocalPath = (hash) ->
      hash = @validHash hash

      if hash?
        return "#{cfg.get 'marianne path'}/#{@validHash hash}"
      else
        return undefined

    ###
      Checks if a User Folder exists for the given User Hash.
    ###
    @exists = (hash) ->
      path = @getPath hash

      if path?
        return fs.existsSync path
      else
        return false

    ###
      Creates a new User Account with the given User Hash or User Name and
      Password combination.
    ###
    @create = (username, password, callback) ->
      if callback
        userhash = @getHash username, password
      else if userhash = @validHash username
        callback = password
      else
        return callback new Error('Invalid User Hash')

      if @exists userhash
        return callback new Error('User Hash already exist')
      else
        fs.mkdirp @getPath(userhash), (err) ->
          if err
            log.error "Create User Folder [#{userhash}] failed", err
            return callback err
          else
            log.info "User Folder [#{userhash}] created"
            return callback null, userhash

    @getDisplayName = (userhash) ->
      userpath = @getLocalPath userhash

      return 'invalid' if not userpath?

      for file in fs.readdirSync userpath
        diplay_name = file.match(/^user\.(.+)\.json$/i)?[1]
        return display_name if display_name?

      # If we got to here, no user json file was found
      return 'anonymous'

    @getMetadata = (userhash) ->
      userpath = @getLocalPath userhash

      if not userpath?
        return undefined

      userhash  = @validHash(userhash).from(2)
      anonymous =
        displayName: 'anonymous'

      for file in fs.readdirSync userpath when display_name = file.match /^user\.(.+)\.json$/i
        userjson = fs.readJSONSync "#{userpath}/#{file}"

        if userjson?
          userjson.displayName = display_name[1]

          delete userjson.seedhash
          return userjson

      # If we got to here, no user json file was found
      return anonymous
module.exports = (account, helpers) ->
  q = require 'q'

  class account
    @routes = (router) ->
      router.use require('body-parser').urlencoded()
      router.use require('csurf')

      router.use (err, req, res, next) ->
        res.locals.csrf_token = req.csrfToken
        next()

      router.get '/new' , (req, res) -> res.render 'account/register'
      router.get 'login', (req, res) -> res.render 'account/login'

      router.post '/new', (req, res) ->
        if req.body? and not req.user.loggedIn
          account_create req, res,
            req.body.userhash,
            req.body.username,
            req.body.password,
            req.body.password_repeat
        else
          res.render 'account/register'

      router.post '/login', (req, res) ->
        if req.body? and not req.user.loggedIn
          account_login req, res,
            req.body.userhash,
            req.body.username,
            req.body.password
        else
          res.render 'account/login'

      router.all '/logout', (req, res) ->
        req.session.destroy -> res.redirect '/'

    account_create = (req, res, userhash, username, password, password_repeat) ->
      accountCreatePromise =
        if userhash
          return helpers.user.create userhash
        else
          e = new Error()

          if username?.length < 7
            e.userTooShort = true

          if password?.length < 7
            e.passTooShort = true
          else if password_repeat isnt password
            e.passMismatch = true

          if e.userTooShort? or e.passTooShort? or e.passMismatch?
            deferred = q.defer()
            deferred.reject(e)
            return deferred.promise
          else
            return helpers.user.create username, password

      accountCreatePromise.then (userhash) ->
        req.session.userhash = userhash
        res.redirect '/'
      , ->
        res.render 'account/register', errors: {userTaken: true}

    account_login = (req, res, userhash, username, password) ->
      if not userhash?
        userhash = helpers.user.getHash username, password
      else if not helpers.user.validHash userhash
        return res.render 'account/login'

      if helpers.user.exists userhash
        req.session.userhash = userhash
        res.redirect '/'
      else
        res.render 'account/login', errors: {failed: true}
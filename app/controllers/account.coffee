module.exports = (helpers) ->
  ###
    This Controller handles the Login and Creation of User Accounts, as well as the
    upload and validation of User Certificates.
  ###
  class AccountController
    ###
      Prepare the Routes that target this Controller.

      @oaram router (Object) express.Router() object
    ###
    @routes = (router) ->
      router.get '/new' , (req, res) -> res.render 'account/register'
      router.get '/login', (req, res) -> res.render 'account/login'

      router.post '/new', (req, res) ->
        if req.body? and not req.user.loggedIn
          account_create req, res,
            req.body.userhash,
            req.body.username,
            req.body.password,
            req.body.password_repeat
        else if req.user.loggedIn
          res.redirect '/'
        else
          res.render 'account/register'

      router.post '/login', (req, res) ->
        if req.body? and not req.user.loggedIn
          account_login req, res,
            req.body.userhash,
            req.body.username,
            req.body.password
        else if req.user.loggedIn
          res.redirect '/'
        else
          res.render 'account/login'

      router.all '/logout', (req, res) ->
        req.session.destroy -> res.redirect '/'

    ###
      Process the creation of an Account.
    ###
    account_create = (req, res, userhash, username, password, password_repeat) ->
      account_created = (err) ->
        if err?
          if Object.isArray err
            res.errors.addValidation err
          else
            res.errors.addFatal 'blacksam.register.exists'

          res.render 'account/register'
        else
          account_login req, res, userhash
      
      if helpers.user.validHash userhash
        helpers.user.create userhash, account_created
      else
        if not username? or username.length < 7
          res.errors.addValidation 'username'

        if not password? or password.length < 7
          res.errors.addValidation 'password'
        else if password_repeat isnt password
          res.errors.addValidation 'password_repeat'

        if res.errors.validation.length > 0
          account_created e
        else
          helpers.user.create username, password, account_created

    ###
      Process an Account login.
    ###
    account_login = (req, res, userhash, username, password) ->
      if userhash?.length is 0
        userhash = helpers.user.getHash username, password
      else if not helpers.user.validHash userhash
        res.errors.addFatal 'blacksam.login.invalid'
        return res.render 'account/login'


      # NOTE: This Login process is "insecure" since capturing the User Hash
      #       in-transit could allow easy impersonation of users. The initial
      #       version of BlackSam won't address this, as Tor or SSL are expected
      #       to be used for communicating with it, and "sensitive" uploads are
      #       expected to be signed. Maybe a Version 2 of User Hash is required
      #       to enhance the security of this. An issue should be opened to
      #       keep track of this.

      if helpers.user.exists userhash
        req.session.userhash = userhash
        res.redirect '/'
      else
        res.errors.addFatal 'blacksam.login.invalid'
        res.render 'account/login'
###
  Load whatever Middleware is needed.

  @param app (Object) The Express.js app object
###
  
module.exports = (app) ->
  # Middleware includes
  body_parser     = require 'body-parser'
  connect_assets  = require 'connect-assets'
  csrf            = require 'csurf'
  express_session = require 'express-session'
  morgan          = require 'morgan'
  serve_static    = require 'serve-static'
  serve_favicon   = require 'serve-favicon'

  # Favicon goes before Morgan because otherwise we're
  # getting a shit-ton of useless lines in logs
  app.use serve_favicon "#{__dirname}/static/favicon.ico"

  # These are quite obvious
  app.use serve_static "#{__dirname}/static"
  app.use connect_assets paths: [
    "#{__dirname}/../bower_components"
    "#{__dirname}/assets"
  ]

  # Needed to make Bootstrap's Glyphicons work
  # Long-ass routing's used to prevent funny things happening
  app.use '/assets/bootswatch-dist/fonts',
    serve_static "#{__dirname}/../bower_components/bootswatch-dist/fonts"

  # Morgan logs requests from browser. Used ONLY if logging level
  # is info (super verbose).
  if app.get('log level') is 'info'
    app.use morgan 'combined'

  app.use express_session
    secret: app.get 'session secret'
    resave: false
    saveUninitialized: false

  app.use body_parser.urlencoded extended: true

  app.use csrf()
  app.use (req, res, next) ->
    res.locals.csrf_token = req.csrfToken
    next()
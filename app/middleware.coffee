###
  Load whatever Middleware is needed.

  @param mid (Function) The {app.use} function
  @param cfg {Object} The {app.helpers.config} helper class
###
  
module.exports = (mid, cfg) ->
  # Favicon goes before Morgan because otherwise we're
  # getting a shit-ton of useless lines in logs
  #mid require('serve-favicon') "#{__dirname}/assets/favicon.ico"

  # Morgan logs requests from browser
  # Used ONLY if debug mode is set
  if cfg.get 'log level' is 'info'
    mid require('morgan') 'combined'

  # These are quite obvious
  mid require('serve-static') "#{__dirname}/static"
  mid require('connect-assets') paths: [
    "#{__dirname}/../bower_components"
    "#{__dirname}/assets"
  ]

  # Needed to make Bootstrap's Glyphicons work
  # Long-ass routing's used to prevent funny things happening
  mid '/assets/bootswatch-dist/fonts',
    require('serve-static') "#{__dirname}/../bower_components/bootswatch-dist/fonts"

  mid require('express-session')
    secret: cfg.get('session secret')
    resave: false
    saveUninitialized: false

  mid require('body-parser').urlencoded extended: true
  mid require('csurf')
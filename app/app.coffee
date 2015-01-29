###
  This is the very first thing loaded for BlackSam. This instantiates Express, initializes
  the vessel with Controllers and Helpers through the call to other files.

  So everything stays tidy and neat. As a Ship's Deck must be.
###

# Initial includes
express  = require 'express'
blacksam =
  init: require "#{__dirname}/init"
  middleware: require "#{__dirname}/middleware"
  routes: require "#{__dirname}/routes"

# Create the App (obviously) and initialize it
blacksam.init app = express(), 'controllers', (err) ->
  if err?
    (app.log?.error ? console.log) "Error occurred during the load of BlackSam core", err
    return console.trace()

  # Remove the Workers helper from the context
  if app.helpers.worker?
    delete app.helpers.workers

  # Load Middleware
  blacksam.middleware app
  app.log.info "Middleware {middleware} attached"

  for h, helper of app.helpers when helper?.middleware?
    app.use helper.middleware
    app.log.info "Middleware {helpers.%s.middleware()} attached", h

  # Load routing
  blacksam.routes app, express

  # Start the server
  app.listen app.get('port'), ->
    app.log.info "Listening on port #{app.get 'port'} in #{app.settings.env} mode"
    app.log.info "RAM for boot: %s", process.memoryUsage().rss.bytes(), process.memoryUsage()
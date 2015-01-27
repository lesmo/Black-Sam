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
    return app.log.error "Error occurred during the load of BlackSam core: %s", (err?.message ? 'unknown'), err

  # Remove the Workers helper from the context
  if app.helpers.worker?
    delete app.helpers.workers

  app.log.info "BlackSam settings, helpers and controllers loaded"

  # Load Middleware
  blacksam.middleware app
  app.log.info "BlackSam middleware attached"

  for h, helper of app.helpers when helper?.middleware?
    app.use helper.middleware
    app.log.info "Helper middleware {#{h}.middleware()} attached"

  # Load routing
  blacksam.routes app, express
  app.log.info "BlackSam controllers routing initialized"

  # Start the server
  app.listen app.get('port'), ->
    app.log.info "BlackSam listening on port #{app.get 'port'} in #{app.settings.env} mode"
    app.log.info "BlackSam RAM for boot: %s", process.memoryUsage().rss.bytes()
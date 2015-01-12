###
  This is the very first thing loaded for BlackSam. This instantiates Express, initializes
  the vessel with Controllers, Helpers and Workers through the call to other files that
  do each of those jobs.

  So everything stays tidy and neat. As a Ship's Deck must be.
###

# Crate the App (obviously)
express = require 'express'
app = express()

# Load Controllers, Helpers and Workers
require("#{__dirname}/init") app
app.log.info "BlackSam controllers, helpers and settings loaded"

# Load Middleware
require("#{__dirname}/middleware") ((a, b) -> if b? then app.use a, b else app.use a), app.helpers.config
app.log.info "BlackSam Middleware attached"

for h, helper of app.helpers when helper?.middleware?
  app.use helper.middleware
  app.log.info "Helper Middleware {#{h}.middleware()} attached"

# Load routing
app.use '/', require("#{__dirname}/routes") app.controllers, express.Router
app.log.info "BlackSam Controllers routing initialized"

# Start the server
require('http').createServer(app).listen app.get('port'), ->
  app.log.info "BlackSam listening on port #{app.get 'port'} in #{app.settings.env} mode"

# Start Workers
for w, worker of app.workers when app.enabled "run #{w} worker"
  if typeof worker is 'function'
    app.helpers.workers.startForever w, worker
  else if typeof worker.work is 'function'
    app.helpers.workers.startForever w, worker.work
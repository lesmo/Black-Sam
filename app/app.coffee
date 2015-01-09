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

# Load Middleware
require("#{__dirname}/middleware") app.use, app.helpers.config

for h, helper of app.helpers when typeof helper.middleware is 'function'
  app.use helper.middleware

# Load routing
app.use '/', require("#{__dirname}/routes") app.controllers, express.Router

# Start the server
require('http').createServer(app).listen app.get('port'), ->
  console.log "BlackSam listening on port #{app.get 'port'} in #{app.settings.env} mode"

# Start Workers
for w, worker of app.workers when typeof worker is 'function'
  app.helpers.workers.startForever w, worker
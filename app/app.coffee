###
  This is the very first thing loaded for BlackSam. This instantiates Express, initializes
  the vessel with Controllers, Helpers and Workers through the call to other files that
  do each of those jobs.

  So everything stays tidy and neat. As a Ship's Deck must be.
###

# Initial includes
express  = require 'express'
blacksam =
  init: require "#{__dirname}/init"
  middleware: require "#{__dirname}/middleware"
  routes: require "#{__dirname}/routes"

# Create the App (obviously)
app = express()

# Load Controllers, Helpers and Workers
blacksam.init app
app.log.info "BlackSam controllers, helpers and settings loaded"

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

# Start Workers
for w, worker of app.workers when app.enabled "run #{w} worker"
  if typeof worker is 'function'
    app.helpers.workers.startForever w, worker
  else if typeof worker.work is 'function'
    app.helpers.workers.startForever w, worker.work
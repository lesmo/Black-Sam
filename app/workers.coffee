###
  This is the very first thing loaded for BlackSam Workers. This loads the Helpers and
  Workers, and starts them.
###

# Initial includes
express  = require 'express'
blacksam =
  init: require "#{__dirname}/init"

# Initialize the core and load the Workers
blacksam.init app = express(), 'workers', (err) ->
  if err?
    (app.log?.error ? console.log) "Error occurred during the load of BlackSam core: %s", (err?.message ? 'unknown'), err
    return console.trace()

  # Start Workers
  for w, worker of app.workers when app.enabled "run #{w} worker"
    if typeof worker is 'function'
      app.helpers.workers.startForever w, worker
    else if typeof worker.work is 'function'
      app.helpers.workers.startForever w, worker.work

  app.log.info "RAM for boot: %s", process.memoryUsage().rss.bytes(), process.memoryUsage()
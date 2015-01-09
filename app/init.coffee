###
  Load and initialize Helpers, Controllers and Worker. Nothing is, and never must be, run
  on the classes in this file.
###

module.exports = (app) ->
  ### Setup the autoloader ###
  fs = require 'fs'

  autoload = (dir, obj, arg) ->
    for file in fs.readdirSync dir
      path = "#{dir}/#{file}"
      stat = fs.lstatSync path

      if stat.isDirectory()
        autoload path, obj, arg
      else
        cls = file.match(/(.*)(\..*)?/i)[1]
        obj[cls] = require(path) arg

  ### Load Settings ###
  if not app.get('session secret') or app.get('session secret') is 'REPLACE THIS BEFORE STARTNG'
    app.set 'session secret', (Math.random().toString() + '056127539128').slice(2, 20)

  autoload "#{__dirname}/../config", {}, {
    set: app.set
    enable: app.enable
    disable: app.disable
  }

  ### Setup the Express Framework ###
  port = app.get('http port') || process.env.PORT || 3000
  if process.argv.indexOf('-p') >= 0
    port = process.argv[process.argv.indexOf('-p') + 1]

  app.set 'port', port
  app.set 'views', "#{__dirname}/views"
  app.set 'view engine', 'jade'

  ### Setup BlackSam Components ###
  app.helpers = app.locals.helpers = {}
  app.controllers = {}
  app.workers = {}

  # Helpers
  autoload "#{__dirname}/helpers", app.helpers, {
    get: app.get
    enabled: app.enabled
    disabled: app.disabled
  }

  # Controllers
  autoload "#{__dirname}/controllers", app.controllers, app.helpers

  # Workers
  autoload "#{__dirname}/workers", app.workers, app.helpers
###
  Load and initialize Helpers, Controllers and Worker. Nothing is, and never must be, run
  on the classes in this file.
###

module.exports = (app) ->
  ### Setup the autoloader ###
  fs      = require 'fs'
  path    = require 'path'
  logging = require "#{__dirname}/logging"

  # Defined AFTER config is loaded
  logger = null

  autoload = (dir, obj, logcat, args) ->
    if arguments.length is 1
      obj = {}
    else if arguments.length is 3
      args = logcat
      logcat = undefined

    for file in fs.readdirSync dir
      filepath = "#{dir}/#{file}"
      stat = fs.lstatSync filepath
      cls  = file.match(/([0-9a-z]+)(\.[0-9a-z]+)?/i)[1]

      if stat.isDirectory()
        autoload filepath, obj, logcat, args
      else if not obj[cls]?
        req = require filepath
        continue if typeof req isnt 'function'

        if args?
          if not Array.isArray args
            args = [args]
        else
          args = []

        if logcat? and typeof logging is 'function'
          args.push logger "#{logcat}.#{cls}"

        obj[cls] = req.apply null, args
        app.log?.info "Loaded {#{cls}} from #{filepath}"

  readonly_config = {
    get: (k) -> app.get k
    enabled: (k) -> app.enabled k
    disabled: (k) -> app.disabled k
  }

  ### Load Settings ###
  autoload "#{__dirname}/../config", {}, {
    set: (k, v) -> app.set k, v
    enable: (k) -> app.enable k
    disable: (k) -> app.disable k
  }

  # Generate awesome random secret if retarded operator didn't set one
  if not app.get('session secret')? or app.get('session secret') is 'REPLACE THIS BEFORE STARTNG'
    app.set 'session secret', (Math.random().toString() + '056127539128').slice(2, 20)

  # Make all paths absolute
  for path_config in ['marianne', 'sultanna', 'sherlock', 'logs']
    app.set "#{path_config} path", path.resolve(app.get "#{path_config} path")

  ### Setup logging ###
  logger  = logging readonly_config
  app.log = logger('blacksam-core')

  if app.disabled 'log to file'
    app.log.info "Logging to file is disabled, printing logs to console"

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
  autoload "#{__dirname}/helpers"
    , app.helpers
    , 'blacksam-helper'
    , readonly_config
  app.helpers.config = readonly_config

  # Controllers
  autoload "#{__dirname}/controllers"
    , app.controllers
    , 'blacksam-controller'
    , app.helpers

  # Workers
  autoload "#{__dirname}/workers"
    , app.workers
    , 'blacksam-worker'
    , app.helpers
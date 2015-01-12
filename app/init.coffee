###
  Load and initialize Helpers, Controllers and Worker. Nothing is, and never must be, run
  on the classes in this file.
###

module.exports = (app) ->
  ### Setup the autoloader ###
  fs = require 'fs'
  path = require 'path'

  autoload = (dir, obj, logcat, args) ->
    if arguments.length is 1
      obj = {}
    else if arguments.length is 3
      args = logcat
      logcat = undefined

    for file in fs.readdirSync dir
      filepath = "#{dir}/#{file}"
      stat = fs.lstatSync filepath

      if stat.isDirectory()
        autoload filepath, obj, logcat, args
      else if not obj[cls]?
        cls  = file.match(/(.*)(\..*)?/i)[1]

        if args?
          if not args.isArray()
            args = [args]
        else
          args = []

        if logcat? and typeof logging is 'function'
          args.push app.logging "#{logcat}.#{cls}"

        obj[cls] = require(filepath).apply null, args

  ### Load Settings ###
  if not app.get('session secret') or app.get('session secret') is 'REPLACE THIS BEFORE STARTNG'
    app.set 'session secret', (Math.random().toString() + '056127539128').slice(2, 20)

  autoload "#{__dirname}/../config", {}, {
    set: app.set
    enable: app.enable
    disable: app.disable
  }

  ### Setup logging ###
  logging = require "#{__dirname}/logging", {
    get: app.get
    enabled: app.enabled
    disabled: app.disabled
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
  autoload "#{__dirname}/helpers"
    , app.helpers
    , 'blacksam-helper'
    , {
      get: app.get
      enabled: app.enabled
      disabled: app.disabled
    }

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
###
  Load and initialize Helpers, Controllers and Worker. Nothing is, and never must be, run
  on the classes in this file.
###
module.exports = (app, components..., callback) ->
  # People will be people... assert there's shit to do first
  if components?.length < 1
    return callback new Error('blacksam.core.noComponents')
  else
    components = components.flatten()

  # Setup the auto-loader
  fs      = require 'fs'
  path    = require 'path'
  async   = require 'async'
  logging = require "#{__dirname}/logging"

  autoload = (dir, obj = {}, args..., callback) ->
    if args?.length > 0
      args = args.flatten()

    async.waterfall [
      # Read files in directory
      (next_step) ->
        fs.readdir dir, next_step

      # Filter out non js/coffee files
      (files, next_step) ->
        async.filter files
        , (file, next_file) ->
          fs.lstat "#{dir}/#{file}", (err, file_stats) ->
            if err?
              next_file false
            else if file_stats.isFile()
              next_file file.match /\.(coffee|js)$/i
            else
              next_file false
        , (files) ->
          next_step null, files

      # Load the files' and call their callback
      (files, next_step) ->
        async.each files
          , (file, next_file) ->
            class_name = file.match(/(.+)\.(coffee|js)$/i)[1]

            # Avoid over-writing already loaded classes
            if obj[class_name]?
              return next_file new Error('blacksam.core.memoryOverwrite')

            file_path = "#{dir}/#{file}"
            required  = require(file_path)

            if not required?
              return next_file new Error('blacksam.core.loadError')

            if typeof required is 'function'
              obj[class_name] = required.apply null, args
            else
              obj[class_name] = required

            app.log?.info "Loaded {%s}", class_name, file_path: file_path
            next_file()
          , next_step
    ], callback

  readonly_config =
    get: (k) -> app.get k
    enabled: (k) -> app.enabled k
    disabled: (k) -> app.disabled k

  write_config = Object.merge readonly_config,
    set: (k, v) -> app.set k, v
    enable: (k) -> app.enable k
    disable: (k) -> app.disable k

  async.waterfall [
    # Load settings
    (next_step) ->
      autoload "#{__dirname}/../config", null, write_config, next_step

    # Tweak settings
    (next_step) ->
      # Generate awesome random secret if retarded operator didn't set one
      if not app.get('session secret')? or app.get('session secret') is 'REPLACE THIS BEFORE STARTNG'
        app.set 'session secret', (Math.random().toString() + '056127539128').slice(2, 20)

      # Make all paths absolute
      for path_config in ['marianne', 'sultanna', 'sherlock', 'logs']
        app.set "#{path_config} path", path.resolve(app.get "#{path_config} path")

      # Get port based on overriding precedence
      port = app.get('http port') or process.env.PORT or 3000
      if process.argv.indexOf('-p') >= 0
        port = process.argv[process.argv.indexOf('-p') + 1]

      # Set stuff for Express.js
      app.set 'port', port
      app.set 'views', "#{__dirname}/views"
      app.set 'view engine', 'jade'

      next_step()

    # Prepare logging
    (next_step) ->
      logger  = logging readonly_config
      app.log = logger('blacksam-core')

      if app.disabled 'log to file'
        app.log.info "Logging to file is disabled, only printing logs to console"

      app.log.profile 'Components loading'
      next_step null, logger

    # Load the Helpers
    (logger, next_step) ->
      app.log.info 'Loading helpers...'

      autoload "#{__dirname}/helpers"
        , app.helpers = {}
        , [app.helpers, readonly_config, logger 'blacksam-helpers']
        , (err) ->
          next_step err, logger

    # Load the requested components
    (logger, next_step) ->
      components.remove 'helpers'

      async.each components
        , (component, next_component) ->
          app.log.info "Loading #{component}..."

          autoload "#{__dirname}/#{component}"
            , app[component] ? app[component] = {}
            , [app.helpers, readonly_config, logger "blacksam-#{component}"]
            , next_component
        , next_step

    # Finalize core-loading profiling
    (next_step) ->
      app.log.profile 'Components loading'
      next_step()
  ], callback
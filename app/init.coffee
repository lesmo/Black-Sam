module.exports = (app) ->
  ### Load the autoloader ###
  app.helpers = require "#{__dirname}/autoload"

  ### Configurations ###
  # These are the defaults
  app.set 'max file size', 1024 * 1024 * 1024 #1mb
  app.set 'session secret', (Math.random().toString() + '056127539128').slice(2, 20)

  app.set 'marianne path', "#{__dirname}/../marianne"
  app.set 'sherlock path', "#{__dirname}/../sherlock"
  app.set 'sultanna path', "#{__dirname}/../sultanna"

  app.helpers.autoload "#{__dirname}/../config", {
    set: app.set
    enable: app.enable
    disable: app.disable
  }

  # Helpers
  app.helpers.autoload "#{__dirname}/helpers", app.helpers = app.locals.helpers = {}, {
    get: app.get
    enabled: app.enabled
    disabled: app.disabled
  }

  # Controllers
  app.helpers.autoload "#{__dirname}/controllers", app.controllers = {}, app.helpers

  # Express configuration
  port = app.get('http port') || process.env.PORT || 3000
  if process.argv.indexOf('-p') >= 0
    port = process.argv[process.argv.indexOf('-p') + 1]

  app.set 'port', port
  app.set 'views', "#{__dirname}/views"
  app.set 'view engine', 'jade'
module.exports = (app) ->
  # Autoloader
  app.helpers = require "#{__dirname}/autoload"

  # Controllers
  app.helpers.autoload "#{__dirname}/controllers", app.controllers = {}

  # Helpers
  app.helpers.autoload "#{__dirname}/helpers", app.controllers.helpers = app.locals.helpers = {app: app}

  # Configuration
  port = process.env.PORT || 3000
  if process.argv.indexOf('-p') >= 0
    port = process.argv[process.argv.indexOf('-p') + 1]

  app.set 'port', port
  app.set 'views', "#{__dirname}/views"
  app.set 'view engine', 'jade'

  app.set 'marianne_dir', "#{__dirname}/../marianne"
  app.set 'sherlock_dir', "#{__dirname}/../sherlock"
  app.set 'sultanna_dir', "#{__dirname}/../sultanna"

  app.set 'session_secret', '1234'
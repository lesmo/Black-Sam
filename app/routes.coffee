module.exports = (app) ->
  express = require('express')
  router  = express.Router()

  # Main Controller routing
  app.controllers.main?.routes(router)

  # Pre-processing for responses
  app.use helpers.response.middleware
  app.use helpers.user.middleware

  # Controllers routing
  for controllerString, controller of app.controllers
    continue if controllerString is 'main'

    controller_route = express.Router()
    controller.routes(controller_route)

    router.use '/' + controllerString, controller_route

  # Error handling (No previous route found. Assuming it’s a 404)
  router.all '/*', (req, res) ->
    res.render '404', status: 404, view: 'four-o-four'

  return router
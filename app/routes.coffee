###
  Initialize Controllers' Routing. Access to the Main {app} object isn't available,
  because you really don't need it.

  {controllers] is the Controllers object in {app.controllers}. The {Router} is a
  direct pointer to {express.Router} function/constructor.
###
module.exports = (controllers, Router) ->
  router = Router()

  # Main Controller routing directly in root
  controllers.main?.routes router

  # Controllers routing
  for controllerString, controller of controllers
    continue if controllerString is 'main'
    continue if typeof controller.routes isnt 'function'

    controller_router = Router()
    controller.routes controller_route

    router.use '/' + controllerString, controller_router

  # Error handling (No previous route found. Assuming it’s a 404)
  router.all '/*', (req, res) -> res.status(404).render '404'

  return router
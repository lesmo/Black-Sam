###
  Initialize Controllers' Routing. Access to the Main {app} object isn't available,
  because you really don't need it.

  {controllers] is the Controllers object in {app.controllers}. The {Router} is a
  direct pointer to {express.Router} function/constructor.
###
module.exports = (app, express) ->
  # Main Controller routing directly in root
  app.controllers.main.routes app
  app.log.info "Initialized routes for {main} Controller"

  # Controllers routing
  for controllerString, controller of app.controllers
    continue if controllerString is 'main'
    continue if not controller.routes?

    controller_router = express.Router()
    controller.routes controller_router

    app.use "/#{controllerString}", controller_router
    app.log.info "Initialized routes for {#{controllerString}} Controller"
  
  # Error handling (No previous route found. Assuming it’s a 404)
  app.all '/*', (req, res) -> res.status(404).render '404'
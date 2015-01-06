module.exports = (controllers) ->
  class controllers.main
    @routes = (router) ->
      router.get '/', (req, res) -> res.render 'index'
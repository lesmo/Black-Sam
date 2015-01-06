module.exports = (main) ->
  class main
    @routes = (router) ->
      router.get '/', (req, res) -> res.render 'index'
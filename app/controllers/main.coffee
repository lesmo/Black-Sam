###
  This Controller's only job is to render the Home Page. Nothing more.
###
module.exports = () ->
  class main
    @routes = (router) ->
      router.all '/', (req, res) -> res.render 'index'
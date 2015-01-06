module.exports = (helpers) ->
  class helpers.response
    @middleware = (err, req, res, next) ->
      if req.query?.aj is 'ax'
        res.locals.useAjaxLayout = true
      else if req.query?.ba is 're'
        res.locals.useBareLayout = true

      next()
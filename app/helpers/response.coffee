module.exports = () ->
  ###
    Pre-process response output.
  ###
  class response
    ###
      Check if the request has to be "bare", with no navbar or fancy stuff,
      or "ajax", without even a body tag and whatnot.
    ###
    @middleware = (err, req, res, next) ->
      if req.query?.aj is 'ax'
        res.locals.useAjaxLayout = true
      else if req.query?.ba is 're'
        res.locals.useBareLayout = true

      next()
module.exports = () ->
  ###
    Pre-process response output.
  ###
  class ResponseHelper
    ###
      Check if the request has to be "bare", with no navbar or fancy stuff,
      or "ajax", without even a body tag and whatnot.
    ###
    @middleware = (req, res, next) ->
      if req.query?.aj is 'ax'
        res.locals.useAjaxLayout = true
      else if req.query?.ba is 're'
        res.locals.useBareLayout = true

      res.locals.clientCrippledUpload =
        req.headers['user-agent']?.has /// (
          ios
          | windows\ phone
          | playstation
          | xbox
        ) ///i

      next()
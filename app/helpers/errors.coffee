module.exports = (helpers, cfg, log) ->
  class ErrorsHelper
    constructor: (res) ->
      @res = res
      @fatal = []
      @validation = []

    types: {
      'blacksam.login.invalid': 'Userhash is invalid or does not exist.'
      'blacksam.register.exists': 'Userhash already exists.'
      'blacksam.upload.empty': 'No Magnet Link or Torrent file uploaded.'
      'blacksam.upload.invalid': 'Invalid Magnet Link or Torrent file uploaded.'
      'blacksam.upload.exists': 'Torrent is already stored.'
      'blacksam.upload.failed': 'Torrent upload failed.'
      'blacksam.upload.index_failed': 'Torrent upload indexing failed.'
    }

    addFatal: (error, meta) ->
      if Object.isString error
        if @types[error]?
          e = new Error @types[error]
          e.type = error

          if meta?
            e = Object.merge e, meta
        else
          e = new Error(error)
      else
        e = error

      @fatal.add e
      return e
    addFatalClient: @addFatal

    addValidation: (field, error) ->
      if not error?
        error = 'Invalid input'

      if Object.isArray error
        @addValidation e for e in error
      else
        @validation.add field: field, message: error
    addValidationClient: @addValidation

  return middleware: (req, res, next) ->
    res.locals.errors = res.errors = new ErrorsHelper(res)
    next()
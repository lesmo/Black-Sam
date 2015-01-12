module.exports = (cfg) ->
  class fakeLogger
    @log = @warn = @info = @error = () ->

  winston = require('winston')
  loggers = {}

  return (component) ->
    if loggers[component]?
      return loggers[component]
    else if cfg.get 'log level'
      transports = [
        new winston.transports.Console
          level: cfg.get 'log level'
      ]

      if not cfg.disabled 'log to file'
        transports.push new winston.transports.File
          filename: "#{cfg.get 'logs path'}/#{component}.log",
          level: cfg.get 'log level'

      return loggers[component] =
        new winston.Logger transports: transports
    else
      return fakeLogger
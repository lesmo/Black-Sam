module.exports = (cfg) ->
  class fakeLogger
    @log = @warn = @info = @error = () ->

  winston = require('winston')
  loggers = {}

  return (component) ->
    if loggers[component]?
      return loggers[component]
    else
      return loggers[component] =
        if cfg.get 'log level'
          new winston.Logger transports: [
            new winston.transports.Console {
              level: cfg.get 'log level'
            }
            new winston.transports.File {
              filename: "#{cfg.get 'logs path'}/#{component}.log",
              level: cfg.get 'log level'
            }
          ]
        else
          fakeLogger
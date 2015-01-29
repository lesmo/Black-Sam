module.exports = (cfg) ->
  winston = require('winston')
  loggers = {}

  class FakeLogger
    for level in Object.keys(winston.levels).include('profile')
      @[level] = ->

  class LoggerMiddleware
    middleLog = (level) -> (args...) =>
      if Object.isString args[0]
        args[0] = "#{@component}: #{args[0]}"

      @logger[level].apply @logger, args

    constructor: (@component, @logger) ->
      @component = @component.spacify()

      for level in Object.keys(@logger.levels).include('profile')
        @[level] = middleLog.apply this, [level]

    category: (class_name) ->
      new LoggerMiddleware "#{@component} (#{class_name})", @logger

  return (component) ->
    if loggers[component]?
      return loggers[component]
    else if cfg.get 'log level'
      transports = [
        new winston.transports.Console
          level: cfg.get 'log level'
          colorize: true
      ]

      if not cfg.disabled 'log to file'
        transports.push new winston.transports.DailyRotateFile,
          filename: "#{cfg.get 'logs path'}/#{component}"
          level: cfg.get 'log level'

      return loggers[component] =
        new LoggerMiddleware component,
          new winston.Logger transports: transports
    else
      return FakeLogger
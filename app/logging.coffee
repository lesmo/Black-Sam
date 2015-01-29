module.exports = (cfg) ->
  winston = require('winston')
  loggers = {}

  logger_methods = ['log', 'warn', 'info', 'error', 'profile']

  class FakeLogger
    for level in logger_methods
      @[level] = () ->

  class LoggerMiddleware
    middleLog = (level, class_name) -> (args...) =>
      if Object.isString args[0]
        args[0] = "#{@component} (#{class_name}): #{args[0]}"

      @logger[level].apply @logger, args

    constructor: (@component, @logger) ->
      @component = @component.spacify()

      for level in logger_methods
        @[level] = middleLog.apply this, [level, 'core']

    category: (class_name) ->
      category = {}

      for level in logger_methods
        category[level] = middleLog.apply this, [level, class_name]

      return category

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
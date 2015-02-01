module.exports = (helpers, cfg, log) ->
  async = require 'async'
  trycatch = require 'trycatch'

  class WorkersHelper
    workers_running = []

    ###
      Determines whether a Worker is currently working.

      @param name (String) Worker name
    ###
    @isRunning = (name) -> not not workers_running.find name.toLowerCase()

    ###
      Starts a Worker that will be run forever, however each run occurs after
      configured timespan since last one.
    ###
    @startForever = (name, work, fail_callback) ->
      name = name.toLowerCase()

      if workers_running.find name
        log.error "Worker {#{name}} already started!"
        return async.nextTick -> fail_callback?()
      else
        log.info "Worker [#{name}] started"

      async.forever (next) ->
        workers_running.add name

        async.nextTick ->
          async.retry cfg.get('max worker fails')
            , (finish) ->
              trycatch ->
                work(finish)
              , (err) ->
                finish(err)
            , (err) ->
              workers_running.remove name

              if err
                next err
              else if cfg.get "worker #{name} timespan"
                setTimeout next, cfg.get "worker #{name} timespan"
              else
                setTimeout next, cfg.get 'worker timespan'
      , (err) ->
        log.error "Worker {#{name}} failed max number of times", err

        if err.stack?
          console.log err.stack

        if cfg.enabled 'die on max worker fails'
          process.exit 1
        else
          fail_callback? err
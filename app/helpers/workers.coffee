module.exports = (helpers, cfg, log) ->
  async = require 'async'

  class workers
    worker_fails = {}
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
        return fail_callback?()
      else
        log.info "Worker [#{name}] started"

      async.forever (next) ->
        workers_running.add name

        work (err) ->
          workers_running.remove name

          if err
            next err
          else if helpers.config.get "worker #{name} timespan"
            setTimeout next, helpers.config.get "worker #{name} timespan"
          else
            setTimeout next, helpers.config.get 'worker timespan'
      , (err) ->
        if worker_fails[name]?
          worker_fails[name]++
        else
          worker_fails[name] = 1

        # Only re-run the Worker if it's still within configured threshold
        if worker_fails[name] < cfg.get 'max worker fails'
          log.warn "Worker [#{name}] failed for the #{worker_fails[name].ordinalize()} time, restarting...", err
          console.trace()
          @startForever name, work, fail_callback
        else
          delete worker_fails[name]

          if cfg.enabled 'die on max worker fails'
            log.error "Worker {#{name}} failed for the #{worker_fails[name].ordinalize()} time, killing BlackSam"
            process.exit 1
          else
            log.error "Worker {#{name}} failed for the #{worker_fails[name].ordinalize()} time, won't be restarted"
            fail_callback? err
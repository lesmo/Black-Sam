module.exports = (helpers, cfg, log) ->
  async = require 'async'

  class workers
    worker_fails = {}

    @startForever = (name, work, fail_callback) ->
      log.info "Worker [#{name}] started"

      async.forever work, (err) ->
        worker_fails[name] = 0 if not worker_fails[name]?
        worker_fails[name]++

        # Only re-run the Worker if it's still within reasonable threshold
        if worker_fails < app.get 'max worker fails'
          log.warn "Worker [#{name}] failed for the #{worker_fails.ordinalize()} time, restarting...", err
          @startForever name, worker, fail_callback
        else
          delete worker_fails[name]

          if app.enabled 'die on max worker fails'
            log.error "Worker [#{name}] failed for the #{worker_fails.ordinalize()} time, killing BlackSam"
            process.exit 1
          else
            log.error "Worker [#{name}] failed for the #{worker_fails.ordinalize()} time, won't be restarted"
            fail_callback? err
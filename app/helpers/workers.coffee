module.exports = (cfg) ->
  async = require 'async'

  class workers
    worker_fails = {}

    @startForever = (name, work, fail_callback) ->
      async.forever work, (err) ->
        # TODO: Log the error

        worker_fails[name] = 0 if not worker_fails[name]?
        worker_fails[name]++

        # Only re-run the Worker if it's still within reasonable threshold
        if worker_fails < app.get 'max worker fails'
          worker_spawner name, worker
        else
          delete worker_fails[name]

          if app.enabled 'debug'
            # TODO: Kill BlackSam if in debug mode
          else
            fail_callback? err
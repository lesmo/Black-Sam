# Do initial setup
app = require('express')()
require("#{__dirname}/init")(app)

# Load app-wide modules and configure them
#app.use require('serve-favicon')("#{__dirname}/assets/favicon.ico")
app.use require('morgan')('combined')
app.use require('serve-static')("#{__dirname}/static")
app.use '/assets', require('serve-static')("#{__dirname}/../bower_components") # needed to make bootstrap glyphicons work
app.use require('connect-assets')(
    paths: [
      "#{__dirname}/../bower_components",
      "#{__dirname}/assets"
    ]
)
app.use require('express-session') {
  secret: app.get('session_secret')
}

# Load routing
app.use '/', require("#{__dirname}/routes")(app)

# Start the server
require('http').createServer(app).listen app.get('port'), ->
  console.log "BlackSam listening on port #{app.get 'port'} in #{app.settings.env} mode"
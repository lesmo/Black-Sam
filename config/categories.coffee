###
  Available categories are shown here. These are shown to the users during upload,
  and these are the only categories accepted during synchronization with other
  ships.

  It's recommended that you don't mess with these, because if someone uploads
  Torrents to a category not in other Ships' configuration, those Ships will
  ignore it and never sync nor show them in search results.
###
module.exports = (config) ->
  # Category names must be lowercase, or they'll be ignored
  config.set 'categories', {
    anime: []
    applications: []
    books: []
    code: []
    documents: []
    games: []
    movies: []
    music: []
    images: []
    porn: []
    tv: []
    others: []
  }
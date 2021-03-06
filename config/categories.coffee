###
  Available categories are shown here. These are shown to the users during upload,
  and these are the only categories accepted during synchronization with other
  ships.

  It's recommended that you don't mess with these, because if someone uploads
  Torrents to a category not in other Ships' cfguration, those Ships will
  ignore it and never sync nor show them in search results.
###
module.exports = (cfg) ->
  # Category names must be lowercase, or chaos will ensue.
  # If you remove any, remember users might try to upload
  # wrongly-categorized content.
  cfg.set 'categories', {
    audio: [
      'music'
      'audio books'
      'sound clips'
    ]
    applications: [
      'windows'
      'mac'
      'unix'
      'ios'
      'android'
    ]
    games: [
      'pc'
      'mac'
      'psx'
      'xbox'
      'wii'
      'handheld'
      'ios'
      'android'
    ]
    others: [
      'e-books'
      'comics'
      'pictures'
      'covers'
      'physibles'
      'documents'
    ]
    porn: [
      'movies'
      'dvds'
      'pictures'
      'games'
      '3d'
    ]
    video: [
      'movies'
      'dvds'
      'music'
      'tv'
      '3d'
    ]
  }
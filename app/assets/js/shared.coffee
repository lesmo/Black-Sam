$ ->
  # Display javascript only tags
  $('.javascript-only').removeClass('javascript-only')

  # Remove noscript tags for the lulz
  $('noscript').remove()
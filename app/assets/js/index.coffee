$ ->
  searchbox  = $('#search-box')
  searchcats = $('#search-categories li a')

  $('#search-category-select').click ->
    searchcats.each ->
      self   = $(this)
      search = searchbox.val().replace /cat:[a-z]+(.\[a-z]+)/i, ''

      self.attr 'href', "/search?q=cat%3A#{self.data 'category'}%20#{encodeURIComponent search.trim()}"
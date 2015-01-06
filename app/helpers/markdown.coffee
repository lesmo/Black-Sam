module.exports = (helpers) ->
  md = require('markdown').markdown

  helpers.markdown = (input) -> md.toHTML(input)
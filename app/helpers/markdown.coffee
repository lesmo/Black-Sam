###
  This is just a bridge to let Jade templates process Markdown using
    != helpers.markdown(<markdown stuff>)
###
module.exports = () -> require('markdown').markdown.toHtml
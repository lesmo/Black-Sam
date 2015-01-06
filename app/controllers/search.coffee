module.exports = (controllers) ->
  class controllers.search
    @index = controllers.helpers.search.index

    @routes = (router) ->
      router.get '/autocomplete', (req, res) ->
        autocomplete req, res,
          if req.query?.q?.trim().length > 3
            req.query.q.toLowerCase()
          else if req.body?.q?.trim().length > 3
            req.body.q.toLowerCase()
          else
            null
      router.all '/', (req, res) ->
        doSearch req, res,
          if req.query?.q?.trim().length > 4
            req.query.q.toLowerCase()
          else if req.body?.q?.trim().length > 4
            req.body.q.toLowerCase()
          else
            res.redirect('/')
            return 0

    autocomplete = (req, res, query) ->
      if query?
        @index.match query, (err, matches) ->
          if matches?
            res.json suggest: matches
          else
            res.json suggest: []
      else
        res.json suggest: []

    doSearch = (req, res, query, page = 1) ->
      cat_regex   = /cat:(.*)$/i
      index_query =
        query:
          '*': query

      cat_regex_matches = index_query.query['*'].match cat_regex

      if cat_regex_matches?.length > 0
        index_query.query['*'] = query.replace cat_regex, ''
        index_query.filter =
          category: cat_regex_matches[1]

      @index.search {
        query:
          '*':  query
        pageSize: 20
        offset: (page - 1) * 20
      }, (err, res) ->
        res.render 'search', {
          query: res?.query.query['*'],
          results: (hit.document for hit of res?.hits)
          paging:
            current: page
            total  : Math.ceil res?.totalHits / 20
        }
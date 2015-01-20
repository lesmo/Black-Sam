module.exports = (helpers) ->
  class SearchController
    @routes = (router) ->
      router.get '/autocomplete', (req, res) ->
        if req.query?.q?.trim().length > 2
          query = req.query.q.toLowerCase()
        else if req.body?.q?.trim().length > 2
          query = req.body.q.toLowerCase()

        autocomplete req, res, query

      router.all '/', (req, res) ->
        if req.query?.q?.trim().length > 2
          query = req.query.q.toLowerCase().trim()
        else if req.body?.q?.trim().length > 2
          query = req.body.q.toLowerCase().trim()

        if req.query?.p?
          page = parseInt req.query.p
        else if req.body?.p?
          page = parseInt req.body.p

        if query?
          doSearch req, res, query, page
        else
          res.redirect '/'

    autocomplete = (req, res, query) ->
      if not query?
        return res.json suggest: []

      @index.match query, (err, matches) ->
        if matches?
          res.json suggest: matches
        else
          res.json suggest: []

    doSearch = (req, res, query_str, page = 1) ->
      page = 1 if page < 1

      cat_regex   = /cat:([a-z]+)(\.([a-z]+))?/i
      index_query =
        query:
          '*': query_str
        pageSize: 20
        offset: (page - 1) * 20

      cat_regex_matches = query_str.match cat_regex

      if cat_regex_matches?
        index_query.query['*'] = query_str.replace cat_regex, ''
        index_query.filter =
          category: [cat_regex_matches[1]]

        if cat_regex_matches[3]?
          index_query.filter.subcategory = [cat_regex_matches[3]]

      index_query.query['*'] = index_query.query['*'].split(' ')

      helpers.search.index.search index_query, (err, results) ->
        if not results?
          return res.status(500).render '500', error: err

        results = (hit.document for hit in results.hits)

        res.render 'search',
          query: query_str,
          results: results
          paging:
            current: page
            total  : Math.ceil results?.totalHits / 20

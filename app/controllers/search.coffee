module.exports = (helpers) ->
  class search
    @routes = (router) ->
      router.get '/autocomplete', (req, res) ->
        autocomplete req, res,
          if req.query?.q?.trim().length > 2
            req.query.q.toLowerCase()
          else if req.body?.q?.trim().length > 2
            req.body.q.toLowerCase()
          else
            null
      router.all '/', (req, res) ->
        query =
          if req.query?.q?.trim().length > 2
            req.query.q.toLowerCase().trim()
          else if req.body?.q?.trim().length > 2
            req.body.q.toLowerCase().trim()
          else
            null
        page =
          if req.query?.p?
            parseInt req.query.p
          else if req.body?.p?
            parseInt req.body.p
          else
            1

        if query?
          doSearch req, res, query, page
        else
          res.redirect '/'

    autocomplete = (req, res, query) ->
      if query?
        @index.match query, (err, matches) ->
          if matches?
            res.json suggest: matches
          else
            res.json suggest: []
      else
        res.json suggest: []

    doSearch = (req, res, query_str, page = 1) ->
      page = 1 if page < 1

      cat_regex   = /cat:([a-z]+)(\.([a-z]+))?/i
      index_query =
        query: {'*': query_str}
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
        results = (hit.document for hit in results.hits)

        if results?
          res.render 'search',
            query: query_str,
            results: results
            paging:
              current: page
              total  : Math.ceil results?.totalHits / 20
        else
          res.status(500).render '500', error: err
module.exports = (helpers) ->
  class search
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
        query =
          if req.query?.q?.trim().length > 4
            req.query.q.toLowerCase().trim()
          else if req.body?.q?.trim().length > 4
            req.body.q.toLowerCase().trim()
          else
            null
        page =
          if req.query?.p?
            parseInt req.query.p
          else if req.body?.p?
            parseInt req.body.p
          else
            0

        if query?
          doSearch req, res, query, (page or 1)
        else
          res.redirect('/')

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

      cat_regex   = /cat:(.*)$/i
      index_query = query: {'*': query_str}

      cat_regex_matches = index_query.query['*'].match cat_regex

      if cat_regex_matches?.length > 0
        index_query.query['*'] = query_str.replace cat_regex, ''
        index_query.filter =
          category: cat_regex_matches[1]

      helpers.search.index.search {
        query: index_query
        pageSize: 20
        offset: (page - 1) * 20
      }, (err, res) ->
        if not err and res
          res.render 'search', {
            query: query_str,
            results: (hit.document for hit of res?.hits)
            paging:
              current: page
              total  : Math.ceil res?.totalHits / 20
          }
        else
          res.status(500).render '500', error: err
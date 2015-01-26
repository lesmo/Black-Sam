module.exports = (helpers, cfg, log) ->
  class CryptoHelper
    @js = cryptojs = require('crypto-js')

    class @user
      @getHash = (username, password) ->
        hash = username + password
        hash = cryptojs.SHA512(hash).toString().toUpperCase()
        hash = cryptojs.SHA256(hash).toString().toUpperCase()
        hash = cryptojs.RIPEMD160(hash).toString().toUpperCase()

        return hash

      @getLockHash = (username, password) ->
        if password?
          hash = username + password
        else
          hash = username.toUpperCase()

        return cryptojs.SHA512(hash).toString().toUpperCase()

      @validJson = (userhash, jsonpath) ->
        if not Object.isString jsonpath
          json = jsonpath
        else
          name_match = jsonpath.match /user\.(.+)\.json$/i
          json = fs.readJsonSync jsonpath, throws: false

          if json? and name_match?
            json.displayName = name_match[1]

        if json?.seedhash?.toUpperCase?
          json.seedhash = json.seedhash.toUpperCase()
        else
          return undefined

        calculated_userhash = cryptojs.RIPEMD160(json.seedhash).toString()

        if calculated_userhash.toUpperCase() isnt userhash.toUpperCase()
          return undefined
        else
          delete json.seedhash # just in case
          return json
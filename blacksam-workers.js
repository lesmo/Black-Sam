/**
 * S U R P I S E !
 *
 * We don't do shit here. Everything's beautiful CoffeeScript, and it's not
 * pre-compiled, it's parsed on the fly because why not. Receive a kind
 * fuck-you if you don't like CoffeeScript.
 *
 * All we do here is load and register CoffeeScript, Sugar.js and finally
 * start BlackSam Workers.
 */

// In case you were wondering, this makes requires load and parse *.coffee files
require("coffee-script").register();

// If there was any doubt, this makes sugar hook itself into our core
require('sugar');

// These are the Korean launch codes... just kidding, it kills you
require("./app/workers.coffee");
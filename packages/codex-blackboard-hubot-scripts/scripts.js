var CoffeeScript = Npm.require('coffee-script');
CoffeeScript.register(); /* needed because hubot scripts are in CoffeeScript */
var scripts = Npm.require('codex-blackboard-hubot-scripts');

HubotScripts = scripts

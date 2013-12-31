#!/usr/bin/env node

// This loads the google package and the drive.coffee implementation into
// a coffeescript REPL for easier debugging.  For example:

// $ private/gdrive-tester.js
// coffee> share.drive.createPuzzle 'One'
// coffee> share.drive.createPuzzle "Two's Company"
// coffee> share.drive.listPuzzles()
// coffee> share.drive.purge()

// If there are syntax errors in drive.coffee, it's useful to do
// $ coffee -p server/drive.coffee
// to diagnose them; this script will not be particularly useful in that case.

// You will probably need to do:
// $ cd private
// $ npm install coffee-script
// $ npm install googleapis
// $ npm install fibers
// to make this script work.  Eventually I'll figure out how to hack up
// the npm package path to avoid having to do this.

var _private = {};
_private.TOP = __dirname + "/.."
_private.NODE_MODULES_PATH = [
    _private.TOP + "/.meteor/local/build/programs/server/node_modules",
    _private.TOP + "/packages/google/.build/npm/node_modules"
];
_private.fs = require('fs');

// Stub out some Meteor functions
var share = exports;
var Npm = {
  require: function(id) {
    var search = _private.NODE_MODULES_PATH.map(function(p) {
      return p + '/' + id;
    });
    for (var i=0; i<search.length; i++) {
      if (_private.fs.existsSync(search[i]) ||
          _private.fs.existsSync(search[i] + '.js')) {
        return require(search[i]);
      }
    }
    return require(id);
  }
};

_private.Fiber = Npm.require('fibers');
_private.Future = Npm.require('fibers/future');

var Meteor = {
  _wrapAsync: function(f) {
    return function() {
      var args = Array.prototype.slice.call(arguments);
      var fut = new _private.Future();
      var callback = fut.resolver();
      args.push(callback);
      f.apply(this, args);
      return fut.wait();
    };
  }
};
(function() {
  var filename = _private.TOP + "/settings.json";
  Meteor.settings = JSON.parse(_private.fs.readFileSync(filename, 'utf8'));
})();
var EJSON = {
  newBinary: function(size) {
    return new Uint8Array(size);
  }
};
var Assets = {
  getBinary: function(f) {
    var filename = _private.TOP + "/private/" + f;
    var contents = _private.fs.readFileSync(filename);
    var result = EJSON.newBinary(contents.length);
    for (var i=0; i<contents.length; i++) { result[i] = contents[i]; }
    return result;
  }
};

_private.Fiber(function() {
// Load the Google module.
var Google;
_private.filename = _private.TOP + "/packages/google/google.js";
_private.f = _private.fs.readFileSync(_private.filename, "utf8");
_private.f = '(function() {' + _private.f + '})();';
eval(_private.f);

// Load drive.coffee
console.log('Contacting Google Drive...');
_private.coffee = Npm.require('coffee-script');
_private.filename = _private.TOP + '/server/drive.coffee';
_private.f = _private.fs.readFileSync(_private.filename, 'utf8');
_private.f = _private.coffee.compile(_private.f);
eval(_private.f);

// Start a coffee-script REPL, with each eval in its own Fiber
_private.repl = Npm.require('coffee-script/lib/coffee-script/repl').start();
_private.repl.context.Google = Google;
_private.repl.context.share = share;

_private.repl.context.Meteor = Meteor;
_private.repl.context.EJSON = EJSON;
_private.repl.context.Assets = Assets;
_private.repl.context.Npm = Npm;

// debugging aid
_private.repl.context.catcher = function(f) {
  try { return f(); } catch (e) { return e; }
};

_private.repl.eval = (function(oldeval) {
  return function(cmd, context, filename, callback) {
    var that = this;
    _private.Fiber(function() {
      // run the eval in a new Fiber
      oldeval.call(that, cmd, context, filename, callback);
    }).run();
  };
})(_private.repl.eval);

}).run();

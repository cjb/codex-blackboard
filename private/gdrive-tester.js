#!/usr/bin/env node

// This loads the google package and the drive.coffee implementation into
// a node/coffeescript REPL for easier debugging.  For example:

// $ cd private
// $ coffee
// coffee> share = require('./gdrive-tester.js')
// coffee> [drive,jwt,rootFolder] = [share.drive.debug.drive,share.drive.debug.jwt,share.drive.debug.rootFolder]
// coffee> (share.drive.listPuzzles()).then console.log

// If there are syntax errors in drive.coffee, it's useful to do
// $ coffee -p server/drive.coffee
// to diagnose them; this script will not be particularly useful in that case.

// You will probably need to do:
// $ cd private
// $ npm install coffee-script
// $ npm install googleapis
// $ npm install when
// to make this script work.  Eventually I'll figure out how to hack up
// the npm package path to avoid having to do this.

var _private = {};
_private.TOP=__dirname+"/.."
_private.fs = require('fs');
require('when/monitor/console');
// Stub out some Meteor functions
var share = exports;
var Npm = {
    require: require
};
var Meteor = {
};
_private.filename = _private.TOP + "/settings.json";
Meteor.settings = JSON.parse(_private.fs.readFileSync(_private.filename, 'utf8'));
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

// Load the Google module.
var Google;
_private.filename = _private.TOP + "/packages/google/google.js";
_private.f = _private.fs.readFileSync(_private.filename, "utf8");
_private.f = '(function() {' + _private.f + '})();';
eval(_private.f);

// Load drive.coffee
_private.coffee = require('coffee-script');
_private.filename = _private.TOP + '/server/drive.coffee';
_private.f = _private.fs.readFileSync(_private.filename, 'utf8');
_private.f = _private.coffee.compile(_private.f/*, {filename:_private.filename}*/);
eval(_private.f);

exports.Google = Google;

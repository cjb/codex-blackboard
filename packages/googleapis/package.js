Package.describe({
  summary: "Interface with Google APIs server-side"
});

// This module doesn't really require `coffee-script`, but we're going
// to add it to the Npm.depends so that our `gdrive-tester.js` script
// can find and use it.
Npm.depends({"googleapis": "0.4.7", "coffee-script":"1.6.3"});

Package.on_use(function(api) {
  api.use(['ejson'], 'server');
  api.export('Gapi', 'server');
  api.add_files([
    'googleapis.js'
  ], 'server');
});

Package.on_test(function(api) {
});

Package.describe({
  summary: "Interface with Twitter APIs server-side"
});

Npm.depends({"twitter": "0.2.5"});

Package.on_use(function(api) {
  api.export('Twitter', 'server');
  api.add_files([
    'twitter.js'
  ], 'server');
});

Package.on_test(function(api) {
});

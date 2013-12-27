Package.describe({
  summary: "Interface with Google Drive API from server"
});

Npm.depends({"googleapis": "0.4.7", "when": "2.7.1"});

Package.on_use(function(api) {
  api.use(['ejson'], 'server');
  api.export('Google', 'server');
  api.add_files([
    'google.js'
  ], 'server');
});

Package.on_test(function(api) {
});

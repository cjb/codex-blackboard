Package.describe({
  name: 'codex-blackboard-hubot-scripts',
  summary: 'Hubot scripts for codex blackboard',
  version: '2.1.1',
  git: 'https://github.com/cscott/codex-blackboard-hubot-scripts.git'
});

Npm.depends({
    // it is annoying that Meteor requires an exact hash here :(
    "codex-blackboard-hubot-scripts": "https://github.com/cscott/codex-blackboard-hubot-scripts/tarball/423818ba01f3289f6c7de7c42ab860a601328e4e",
    "coffee-script": "1.10.0",
});

Package.onUse(function(api) {
  api.versionsFrom('METEOR@0.9.0');
  api.addFiles([
    'scripts.js'
  ], 'server');
  if (api.export) { api.export('HubotScripts', 'server'); }
});

Package.onTest(function(api) { /* no tests */ });

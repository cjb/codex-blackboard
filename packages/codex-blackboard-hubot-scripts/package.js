Package.describe({
  name: 'codex-blackboard-hubot-scripts',
  summary: 'Hubot scripts for codex blackboard',
  version: '1.0.0',
  git: 'https://github.com/cscott/codex-blackboard-hubot-scripts.git'
});

Npm.depends({
    // it is annoying that Meteor requires an exact hash here :(
    "codex-blackboard-hubot-scripts": "https://github.com/cscott/codex-blackboard-hubot-scripts/tarball/f57c178a2faee9b36d07a7905c29093b9824e0b0",
    "coffee-script": "1.8.0"
});

Package.onUse(function(api) {
  api.versionsFrom('METEOR@0.9.0');
  api.addFiles([
    'scripts.js'
  ], 'server');
  if (api.export) { api.export('HubotScripts', 'server'); }
});

Package.onTest(function(api) { /* no tests */ });

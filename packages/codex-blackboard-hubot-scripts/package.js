Package.describe({
  name: 'codex-blackboard-hubot-scripts',
  summary: 'Hubot scripts for codex blackboard',
  version: '2.1.2',
  git: 'https://github.com/cscott/codex-blackboard-hubot-scripts.git'
});

Npm.depends({
    // it is annoying that Meteor requires an exact hash here :(
    "codex-blackboard-hubot-scripts": "https://github.com/cscott/codex-blackboard-hubot-scripts/tarball/f75ead3e1cb1d4047cdbc26b34a052ffb9005400",
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

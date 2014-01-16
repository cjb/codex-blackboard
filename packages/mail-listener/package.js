Package.describe({
	summary: "mail-listener NPM module packaged for Meteor."
});

Npm.depends({ 'mail-listener': '0.6.3' });

Package.on_use(function (api) {
	api.add_files('mail_listener.js', 'server');
});
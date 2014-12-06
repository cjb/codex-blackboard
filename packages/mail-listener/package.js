Package.describe({
	summary: "mail-listener2 NPM module packaged for Meteor."
});

Npm.depends({ 'mail-listener2': 'https://github.com/chirag04/mail-listener2/tarball/25f0d2b9e9fff0c2677fbac1316e3d5df56a2b94' });

Package.on_use(function (api) {
	api.export('MailListener', 'server');
	api.add_files('mail_listener.js', 'server');
});

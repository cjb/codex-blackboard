Package.describe({
	summary: "mail-listener2 NPM module packaged for Meteor."
});

Npm.depends({ 'mail-listener2': 'https://github.com/chirag04/mail-listener2/tarball/276077b8e7d25013037d39a99418b6e08c807dcb' });

Package.on_use(function (api) {
	api.export('MailListener', 'server');
	api.add_files('mail_listener.js', 'server');
});

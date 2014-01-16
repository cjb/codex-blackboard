var ML2 = Npm.require('mail-listener2');

MailListener = function(opts) {
    this.ml = new ML2(opts);
};
MailListener.prototype.start = function() {
    return this.ml.start();
};
MailListener.prototype.on = function(name, f) {
    // We need to wrap our callbacks with Meteor.bindEnvironment.
    return this.ml.on(name, Meteor.bindEnvironment(f));
};
// XXX callbacks on methods called on the imap object aren't wrapped.
Object.defineProperty(MailListener.prototype, 'imap', {
    get: function() { return this.ml.imap; }
});

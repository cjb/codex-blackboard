var googleapis = Npm.require('googleapis');
var crypto = Npm.require('crypto');
var when = Npm.require('when');

var globalAuth;

Google = {
  apis: googleapis,
  when: when,

  registerAuth: function(auth) { globalAuth = auth; },

  // Helper functions to execute a google api request, returning a promise.
  exec: function(request, auth) {
    auth = auth || globalAuth;
    if (auth) { request = request.withAuthClient(auth); }
    var deferred = when.defer();
    request.execute(function(err, result) {
      if (err) { deferred.reject(err); }
      else { deferred.resolve(result); }
    });
    return deferred.promise;
  },

  // Helper function to execute a google api request, using a fiber to
  // make it appear synchronous.
  execSync: function(request, auth) {
    auth = auth || globalAuth;
    if (auth) { request = request.withAuthClient(auth); }
    return Meteor._wrapAsync(request.execute).call(request);
  },

  // Helper function to take an arbitrary promise and wait for it.
  wait: function(promise) {
    return Meteor._wrapAsync(function(callback) {
      promise.done(function(result) { callback(null, result); },
                   function(err) { callback(err); });
    }).call();
  },

  // Helper functions to encrypt/decrypt keys from Asset storage

  // takes a string and a password string, returns an EJSON binary
  crypt: function(data, password) {
    password = new Buffer(password, 'utf8'); // encode string as utf8
    var encrypt = crypto.createCipher('aes256', password);
    var output1 = encrypt.update(data, 'utf8', null);
    var output2 = encrypt.final(null);
    var r = EJSON.newBinary(output1.length + output2.length);
    var i;
    for (i=0; i<output1.length; i++) { r[i] = output1[i]; }
    for (i=0; i<output2.length; i++) { r[output1.length + i] = output2[i]; }
    return r;
  },

  // takes an EJSON binary and a password string, returns a string.
  decrypt: function(data, password) {
    password = new Buffer(password, 'utf8'); // encode string as utf8
    var decrypt = crypto.createDecipher('aes256', password);
    data = new Buffer(data); // convert EJSON binary to Buffer
    var output = decrypt.update(data, null, 'utf8');
    output += decrypt.final('utf8');
    return output;
  }
};

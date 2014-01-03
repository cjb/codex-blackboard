var googleapis = Npm.require('googleapis');
var crypto = Npm.require('crypto');

var globalAuth;

Gapi = {
  apis: googleapis,

  registerAuth: function(auth) { globalAuth = auth; },

  // Helper functions to execute a google api request.
  // Execution is synchronous if callback is omitted
  exec: Meteor._wrapAsync(function(request, auth, callback) {
    if (typeof(callback)==='undefined' && typeof(auth)==='function') {
      callback = auth; auth = undefined; // shift args over
    }
    auth = auth || globalAuth;
    if (auth) { request = request.withAuthClient(auth); }
    request.execute(callback);
  }),

  // Helper function to execute google authorization, synchronously
  authorize: Meteor._wrapAsync(function(auth, callback) {
    auth.authorize(callback);
  }),

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

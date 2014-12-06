codex-blackboard
================

Meteor app for coordating solving for our MIT Mystery Hunt team.  To run,
first obtain the password for our google drive account.  Then:

    $ cd codex-blackboard
    $ echo '{ "password":"<password here>" }' > private/settings.json
    $ meteor --settings private/settings.json
    <browse to localhost:3000>

If you don't have the google drive password, you can just omit the
`private/settings.json` file and the `--settings` option to meteor; the app
will skip all the google drive integration steps.

Your code is pushed live to the server as you make changes, so
you can just leave `meteor` running.  Occassionally we make changes to the
database schema -- add new sample data, change how things are organized, etc.
In those cases:

    $ meteor reset
    $ meteor --settings private/settings.json

will wipe the old database and start afresh.

## Installing Meteor

Our blackboard app currently requires Meteor 0.7.2.

At the moment the two ways to install Meteor are:

* just make a git clone of the meteor repo and put it in $PATH, or
* use the package downloaded by their install shell script

The latter option is easier, and automatically downloads the correct
version of meteor and all its dependencies, based on the contents of
`codex-blackboard/.meteor/release`.  Simply cross your finger, trust
in the meteor devs, and do:

    $ curl https://install.meteor.com | /bin/sh

You can read the script and manually install meteor this way as well;
it just involves downloading a binary distribution and installing it
in `~/.meteor`.

If piping stuff from the internet directly to /bin/sh gives you the
willies, then you can also run from a git checkout.  Something like:

    $ cd ~/3rdParty
    $ git clone git://github.com/meteor/meteor.git
    $ cd meteor
    $ git checkout release/0.7.2
    $ cd ~/bin ; ln -s ~/3rdParty/meteor/meteor .

Meteor can run directly from its checkout, and figure out where to
find the rest of its files itself --- but it only follows a single symlink
to its binary; a symlink can't point to another symlink.  If you use a
git checkout, you will be responsible for updating your checkout to
the latest version of meteor when `codex-blackboard/.meteor/release`
changes.

You should probably watch the screencast at http://meteor.com to get a sense
of the framework; you might also want to check out the examples they've
posted, too.

## Working with Google Drive

We use JWT for authenticating with google drive.  The official
documentation is a bit sparse.  I suggest you read the docs for the
[gapitoken] package which describes how to make a `.pem` private key
file for the service account associated with this app.  In order to
avoid publicly exposing the private key in github, we then encrypt
this private key file with a password, stored in `private/settings.json` but
*not* checked in.  The server-side `Gapi.encrypt` function (in
`packages/googleapis/googleapis.js`) can be used to create a properly
encrypted key if the credentials or password ever needs to change.

For development, it is useful to have a scratch drive folder which is
specific to your development install and can be wiped out and reset.
Add a `folder` key to your `private/settings.json` file to name this scratch
folder.  For example:
    {"password":"<password here>","folder":"My Dev Test Folder"}

[gapitoken]: https://npmjs.org/package/gapitoken

## Goals, etc.

The following links should give you a sense of the functionality we're
attempting to reimplement (talk to us if you need a reminder of the
login and password for these):

* http://codex.hopto.org/codex/wiki/All_Puzzles11
* http://codex.hopto.org/codex/wiki/2011_R1P1
* http://codex.hopto.org/show.asp?roomname=r10meta
* http://codex.hopto.org/codex/wiki/Chat_System#Chat_Bot

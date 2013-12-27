codex-blackboard
================

Meteor app for coordating solving for our MIT Mystery Hunt team.  To run:

    $ cd codex-blackboard
    $ meteor
    <browse to localhost:3000>

Note that your code is pushed live to the server as you make changes, so
you can just leave meteor running.  Occassionally we make changes to the
database schema -- add new sample data, change how things are organized, etc.
In those cases:

    $ meteor reset
    $ meteor

will wipe the old database and start afresh.

## Installing Meteor

Our blackboard app currently requires Meteor 0.6.6.3.

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
    $ git checkout release/0.6.6.3
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

## Goals, etc.

The following links should give you a sense of the functionality we're
attempting to reimplement (talk to us if you need a reminder of the
login and password for these):

* http://codex.hopto.org/codex/wiki/All_Puzzles11
* http://codex.hopto.org/codex/wiki/2011_R1P1
* http://codex.hopto.org/show.asp?roomname=r10meta
* http://codex.hopto.org/codex/wiki/Chat_System#Chat_Bot

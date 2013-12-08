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

Our blackboard app currently requires Meteor 0.5.5.

At the moment the two ways to install Meteor are:

* just make a git clone of the meteor repo and put it in $PATH, or
* use the package downloaded by their install shell script

The first option is something like:

    $ cd ~/3rdParty
    $ git clone git://github.com/meteor/meteor.git
    $ cd meteor
    $ git checkout v0.5.5
    $ cd ~/bin ; ln -s ~/3rdParty/meteor/meteor .

Note that meteor can run directly from its checkout, and figure out where to
find the rest of its files itself.  (But it only follows a single symlink
to its binary; a symlink can't point to another symlink.)

The second option is "easier" but gives me the willies.  It's also not clear
how to install archival versions of meteor:

    $ curl https://install.meteor.com | /bin/sh

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

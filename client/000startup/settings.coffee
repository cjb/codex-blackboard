# This file contains various constants used throughout the client code.
'use strict'
settings = share.settings = {}

# this is populated on the client based on the server's --settings
server = Meteor.settings?.public ? {}

# identify this particular client instance
settings.CLIENT_UUID = Random.id()

# used to create gravatars from nicks
settings.DEFAULT_HOST = server.defaultHost ? 'codexian.us'

# used for wiki links
settings.WIKI_HOST = server.wikiHost ? 'http://wiki.codexian.us'

# hunt year, used to make wiki links
settings.HUNT_YEAR = server.huntYear ? 2014

# -- Performance settings --

# subscribe to all rounds/all puzzles, or try to be more granular?
settings.BB_SUB_ALL = server.subAll ? true

# disable PMs (more efficient queries if PMs are disabled)
settings.BB_DISABLE_PM = server.disablePM ? true

# disable special followup formatting in chat to improve client render speed
settings.SLOW_CHAT_FOLLOWUPS = server.slowChatFollowups ? true

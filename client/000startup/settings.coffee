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
settings.WIKI_HOST = server.wikiHost ? 'https://wiki.codexian.us'

# hunt year, used to make wiki links
settings.HUNT_YEAR = server.huntYear ? 2014

# -- Performance settings --

# make fewer people subscribe to ringhunters chat.
settings.BB_DISABLE_RINGHUNTERS_HEADER = server.disableRinghunters ? false

# subscribe to all rounds/all puzzles, or try to be more granular?
settings.BB_SUB_ALL = server.subAll ? true

# disable PMs (more efficient queries if PMs are disabled)
# (PMs are always allows in ringhunters)
settings.BB_DISABLE_PM = server.disablePM ? false

# Also: server.followupStyle
# Options are:
#  'server' (server-side followups),
#  'client' (client-side followups), or
#  'none' (no follow-up rendering)
# This setting is accessed via model.followupStyle()

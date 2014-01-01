# This file contains various constants used throughout the client code.
'use strict'
settings = share.settings = {}

# subscribe to all rounds/all puzzles, or try to be more granular?
settings.BB_SUB_ALL = true

# disable PMs (more efficient queries if PMs are disabled)
settings.BB_DISABLE_PM = true

# identify this particular client instance
settings.CLIENT_UUID = Random.id()

# used to create gravatars from nicks
settings.DEFAULT_HOST = Meteor.settings?.public?.defaultHost or 'codexian.us'

# used for wiki links
settings.WIKI_HOST = Meteor.settings?.public?.wikiHost or 'http://wiki.codexian.us'

# hunt year, used to make wiki links
settings.HUNT_YEAR = Meteor.settings?.public?.huntYear or 2014

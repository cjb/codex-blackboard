'use strict'
model = share.model # import

Meteor.publish 'all-roundsandpuzzles', -> [
  model.RoundGroups.find(), model.Rounds.find(), model.Puzzles.find()
]
Meteor.publish 'all-nicks', -> model.Nicks.find()
Meteor.publish 'all-presence', ->
  # strip out unnecessary fields from presence (esp timestamp) to avoid wasted
  # updates to clients
  model.Presence.find {present: true}, fields:
    timestamp: 0
    foreground_uuid: 0
    present: 0
Meteor.publish 'presence-for-room', (room_name) ->
  model.Presence.find {present: true, room_name: room_name}, fields:
    timestamp: 0
    foreground_uuid: 0
    present: 0

Meteor.publish 'lastread-for-nick', (nick) ->
  nick = model.canonical(nick or '') or null
  model.LastRead.find {nick: nick}

# this is for the "that was easy" sound effect
# everyone is subscribed to this all the time
Meteor.publish 'last-answered-puzzle', ->
  collection = 'last-answer'
  self = this
  uuid = Random.id()

  recent = null
  initializing = true

  max = (doc) ->
    if doc.solved?
      if (not recent?.puzzle) or (doc.solved > recent.solved)
        recent = {solved:doc.solved, puzzle:doc._id}
        return true
    return false

  publishIfMax = (doc) ->
    return unless max(doc)
    self.changed collection, uuid, recent \
      unless initializing
  publishNone = ->
    recent = {solved: model.UTCNow()} # "no recent solved puzzle"
    self.changed collection, uuid, recent \
      unless initializing

  handle = model.Puzzles.find({
    answer: { $exists: true, $ne: null }
  }).observe
    added: (doc) -> publishIfMax(doc)
    changed: (doc, oldDoc) -> publishIfMax(doc)
    removed: (doc) ->
      publishNone() if doc._id is recent?.puzzle

  # observe only returns after initial added callbacks.
  # if we still don't have a 'recent' (possibly because no puzzles have
  # been answered), set it to current time
  publishNone() unless recent?
  # okay, mark the subscription as ready.
  initializing = false
  self.added collection, uuid, recent
  self.ready()
  # Stop observing the cursor when client unsubs.
  # Stopping a subscription automatically takes care of sending the
  # client any 'removed' messages
  self.onStop -> handle.stop()

# limit site traffic by only pushing out changes relevant to a certain
# roundgroup, round, or puzzle
Meteor.publish 'puzzle-by-id', (id) -> model.Puzzles.find _id: id
Meteor.publish 'round-by-id', (id) -> model.Rounds.find _id: id
Meteor.publish 'round-for-puzzle', (id) -> model.Rounds.find puzzles: id
Meteor.publish 'roundgroup-for-round', (id) -> model.RoundGroups.find rounds: id

Meteor.publish 'my-nick', (nick) -> model.Nicks.find canon: model.canonical(nick)

# get recent messages
# paged version: specify page boundary by timestamp, so we can display
# 'more' messages by passing in the timestamp of the first message
# on the current page we're looking at
Meteor.publish 'paged-messages', (room_name, timestamp) ->
  timestamp = (+timestamp) or Number.MAX_VALUE
  model.Messages.find {
    room_name: room_name
    timestamp: $lt: +timestamp
    to: null # no pms
  },
     sort: [['timestamp','desc']]
     limit: model.MESSAGE_PAGE
# same thing, but nick-specific.  Note that between paged-messages and
# paged-messages-nick we'll almost certainly get more than MESSAGE_PAGE
# messages -- but that's ok.  We'll do a limit on the client-side; it's
# worth it because we can share the big query and paged-messages-nick
# should be small/light-weight.
Meteor.publish 'paged-messages-nick', (nick, room_name, timestamp) ->
  timestamp = (+timestamp) or Number.MAX_VALUE
  nick = model.canonical(nick or '') or null
  return (model.Messages.find {}, {limit:0}) unless nick?
  model.Messages.find {
    room_name: room_name
    timestamp: $lt: +timestamp
    $or: [ { nick: nick }, { to: nick } ]
  },
     sort: [['timestamp','desc']]
     limit: model.MESSAGE_PAGE

Meteor.publish 'callins', ->
  model.CallIns.find {},
    sort: [["created","asc"]]

# synthetic 'all-names' collection which maps ids to type/name/canon
Meteor.publish 'all-names', ->
  self = this
  handles = [ 'roundgroups', 'rounds', 'puzzles' ].map (type) ->
    model.collection(type).find({}).observe
      added: (doc) ->
        self.added 'names', doc._id,
          type: type
          name: doc.name
          canon: model.canonical(doc.name)
      removed: (doc) ->
        self.removed 'names', doc._id
      changed: (doc,olddoc) ->
        return unless doc.name isnt olddoc.name
        self.changed 'names', doc._id,
          name: doc.name
          canon: model.canonical(doc.name)
  # observe only returns after initial added callbacks have run.  So now
  # mark the subscription as ready
  self.ready()
  # stop observing the various cursors when client unsubs
  self.onStop ->
    handles.map (h) -> h.stop()

# Publish the 'facts' collection to all users
Facts.setUserIdFilter -> true

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
    $and: [ {answer: $ne: null}, {answer: $exists: true} ]
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

# only publish last page of messages
Meteor.publish 'recent-messages', (nick, room_name) ->
  nick = model.canonical(nick or '') or null
  model.Messages.find {
    room_name: room_name
    $or: [ { nick: nick }, { to: $in: [null, nick] } ]
  },
    sort:[["timestamp","desc"]]
    limit: model.MESSAGE_PAGE

# paged version: specify page boundary by timestamp, so we can display
# 'more' messages by passing in the timestamp of the first message
# on the current page we're looking at
Meteor.publish 'paged-messages', (nick, room_name, timestamp) ->
  nick = model.canonical(nick or '') or null
  model.Messages.find {
    room_name: room_name
    timestamp: $lt: +timestamp
    $or: [ { nick: nick }, { to: $in: [null, nick] } ]
  },
     sort: [['timestamp','desc']]
     limit: model.MESSAGE_PAGE

# same thing for operation log
Meteor.publish 'recent-oplogs', ->
  model.OpLogs.find {}, {sort: [["timestamp","desc"]], limit: 20}

Meteor.publish 'paged-oplogs', (timestamp) ->
  model.OpLogs.find {timestamp: $lt: +timestamp},
     sort: [['timestamp','desc']]
     limit: model.OPLOG_PAGE

Meteor.publish 'callins', ->
  model.CallIns.find {},
    sort: [["created","asc"]]

# synthetic 'all-names' collection which maps ids to type/name/canon
Meteor.publish 'all-names', ->
  self = this
  handles = [ 'roundgroups', 'rounds', 'puzzles', 'callins' ].map (type) ->
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

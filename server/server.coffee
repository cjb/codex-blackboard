Meteor.publish 'all-roundgroups', -> RoundGroups.find()
Meteor.publish 'all-rounds', -> Rounds.find()
Meteor.publish 'all-puzzles', -> Puzzles.find()
Meteor.publish 'all-presence', ->
  # strip out unnecessary fields from presence (esp timestamp) to avoid wasted
  # updates to clients
  Presence.find {present: true}, fields:
    timestamp: 0
    foreground_uuid: 0
    present: 0

# this is for the "that was easy" sound effect
# everyone is subscribed to this all the time
Meteor.publish 'newly-answered-puzzles', ->
  Puzzles.find { $and: [ {answer: $ne: null}, {answer: $exists: true} ] },
    sort: [['solved','desc']]
    limit: 5

# limit site traffic by only pushing out changes relevant to a certain
# roundgroup, round, or puzzle
Meteor.publish 'puzzle-by-id', (id) -> Puzzles.find _id: id
Meteor.publish 'round-by-id', (id) -> Rounds.find _id: id
Meteor.publish 'round-for-puzzle', (id) -> Rounds.find puzzles: id
Meteor.publish 'roundgroup-for-round', (id) -> RoundGroups.find rounds: id

MESSAGE_PAGE = 150 # a page is 150 messages
# only publish last page of messages
Meteor.publish 'recent-messages', (room_name) ->
  Messages.find {room_name: room_name},
    sort:[["timestamp","desc"]]
    limit: MESSAGE_PAGE

# paged version: specify page boundary by timestamp, so we can display
# 'more' messages by passing in the timestamp of the first message
# on the current page we're looking at
Meteor.publish 'paged-messages', (room_name, timestamp) ->
   Messages.find {room_name: room_name, timestamp: $lte: timestamp},
     sort: [['timestamp','desc']]
     limit: MESSAGE_PAGE

# same thing for operation log
OPLOG_PAGE = 150
Meteor.publish 'recent-oplogs', ->
  OpLogs.find {}, {sort: [["timestamp","desc"]], limit: 20}

Meteor.publish 'paged-oplogs', (timestamp) ->
  OpLogs.find {timestamp: $lte: timestamp},
     sort: [['timestamp','desc']]
     limit: OPLOG_PAGE

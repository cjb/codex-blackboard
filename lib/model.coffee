# Blackboard -- data model
# Loaded on both the client and the server

# OpLogs are:
#   _id: mongodb id
#   timestamp: timestamp
#   message: string -- human-readable description of what was done
#   type: string
#   id: string -- type/id give a mongodb reference to the object modified
#                 so we can hyperlink to it.
OpLogs = new Meteor.Collection "oplogs"

# RoundGroups are:
#   _id: mongodb id
#   rounds: [ array of round _ids, in order ]
#   name: string (special name '' for rounds w/o a group)
#   canon: canonicalized version of name, for searching
#   tags: [ { name: "Status", canon: "status", value: "stuck" }, ... ]
RoundGroups = new Meteor.Collection "roundgroups"
if Meteor.isServer
  RoundGroups._ensureIndex {canon: 1}, {unique:true, dropDups:true}

# Rounds are:
#   _id: mongodb id
#   name: string (special name '' for puzzles w/o a round)
#   canon: canonicalized version of name, for searching
#   puzzles: [ array of puzzle _ids, in order ]
#   created: timestamp
#   touched: timestamp -- for special "round" chat, usually metapuzzle
#   last_touch_by: _id of Nick
#   tags: [ { name: "Status", canon: "status", value: "stuck" }, ... ]
Rounds = new Meteor.Collection "rounds"
if Meteor.isServer
  Rounds._ensureIndex {canon: 1}, {unique:true, dropDups:true}

# Puzzles are:
#   _id: mongodb id
#   name: string
#   canon: canonicalized version of name, for searching
#   answer: string (field is null (not missing or undefined) if not solved)
#   created: timestamp
#   solved:  timestamp
#   touched: timestamp
#   last_touch_by: _id of Nick
#   tags: [ { name: "Status", canon: "status", value: "stuck" }, ... ]
#   drive: google drive url or id
Puzzles = new Meteor.Collection "puzzles"
if Meteor.isServer
  Puzzles._ensureIndex {canon: 1}, {unique:true, dropDups:true}

# Nicks are:
#   _id: mongodb id
#   name: string
#   canon: canonicalized version of name, for searching
#   tags: [ { name: "Real Name", canon: "real_name", value: "C. Scott Ananian" }, ... ]
Nicks = new Meteor.Collection "nicks"
if Meteor.isServer
  Nicks._ensureIndex {canon: 1}, {unique:true, dropDups:true}

# Messages
#   body: string
#   nick: canonicalized string (may match some Nicks.canon ... or not)
#   system: boolean (true for system messages, false for user messages)
#   room_name: "<type>/<id>", ie "puzzle/1", "round/1". "general/0" for main chat.
#   timestamp: timestamp
Messages = new Meteor.Collection "messages"
if Meteor.isServer
  Messages._ensureIndex {timestamp:-1}, {}

# Chat room presence
#   nick: canonicalized string, as in Messages
#   room_name: string, as in Messages
#   timestamp: timestamp -- when user was last seen in room
#   foreground: boolean (true if user's tab is still in foreground)
Presence = new Meteor.Collection "presence"
if Meteor.isServer
  Presence._ensureIndex {nick: 1, room_name:1}, {unique:true, dropDups:true}
  Presence._ensureIndex {timestamp:-1}, {}
  # ensure old entries are timed out after 5 min
  Meteor.setInterval ->
    #console.log "Removing entries older than", (UTCNow() - 5*60*1000)
    Presence.remove timestamp: $lt: (UTCNow() - 5*60*1000)
  , 60*1000


# Globals
blackboard = {}

unimplemented = -> throw new Meteor.Error(500, "Unimplemented")
collection = (type) -> switch type
      when "puzzle" then Puzzles
      when "round" then Rounds
      when "roundgroup" then RoundGroups
      when "nick" then Nicks
      else throw new Meteor.Error(400, "Bad collection type")

oplog = (message, type="", id="") ->
  OpLogs.insert { timestamp:UTCNow(), message:message, type:type, id:id }

getTag = (object, name) ->
  (tag.value for tag in (object.tags or []) when tag.canon is canonical(name))[0]

# canonical names: lowercases, all non-alphanumerics replaced with '_'
canonical = (s) ->
  s = s.toLowerCase().replace(/^\s+/, '').replace(/\s+$/, '') # lower, strip
  # suppress 's and 't
  s = s.replace(/[\'\u2019]([st])\b/, "$1")
  # replace all non-alphanumeric with _
  s = s.replace(/[^a-z0-9]+/, '_').replace(/^_/,'').replace(/_$/,'')
  return s

canonicalTags = (tags) ->
  ({name:tag.name,canon:canonical(tag.name),value:tag.value} for tag in tags)

Meteor.methods
  newRoundGroup: (args) ->
    throw new Meteor.Error(400, "missing name") unless args.name
    newRoundGroup =
      name: args.name or ""
      canon: canonical(args.name or "") # for lookup
      tags: canonicalTags(args.tags or [])
      rounds: args.rounds or []
    id = RoundGroups.insert newRoundGroup
    oplog "Created new Round Group: "+args.name
    return RoundGroups.findOne(id)
  renameRoundGroup: (args) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    throw new Meteor.Error(400, "missing name") unless args.name
    RoundGroups.update args.id, $set: name: args.name
    oplog "Renamed Round Group to "+args.name
    return true
  delRoundGroup: (args) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    oplog "Deleted Round Group "+RoundGrounds.findOne(args.id).name
    RoundGroups.remove(args.id)
    return true

  newRound: (args) ->
    throw new Meteor.Error(400, "missing name") unless args.name
    now = UTCNow()
    newRound =
      name: args.name or ""
      canon: canonical(args.name or "") # for lookup
      tags: canonicalTags(args.tags or [])
      puzzles: args.puzzles or []
      created: now
      touched: now
      last_touch_by: args.who or ""
    id = Rounds.insert newRound
    oplog "Created new Round: "+args.name, "round", id
    return Rounds.findOne(id)
  renameRound: (args) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    throw new Meteor.Error(400, "missing name") unless args.name
    Rounds.update args.id, $set: name: args.name
    oplog "Renamed Round to "+args.name, "round", args.id
    # XXX: rename chat room logs?
    return true
  delRound: (args) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    oplog "Deleted Round "+Rounds.findOne(args.id).name
    Rounds.remove(args.id)
    # XXX: delete chat room logs?
    return true

  newPuzzle: (args) ->
    throw new Meteor.Error(400, "missing name") unless args.name
    now = UTCNow()
    newPuzzle =
      name: args.name or ""
      canon: canonical(args.name or "") # for lookup
      tags: canonicalTags(args.tags or [])
      answer: null
      created: now
      solved: null
      touched: now
      last_touch_by: args.who or ""
      drive: args.drive or null
    id = Puzzles.insert newPuzzle
    # XXX: create google drive folder
    oplog "Added new puzzle: "+args.name, "puzzle", id
    return Puzzles.findOne(id)
  renamePuzzle: (args) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    throw new Meteor.Error(400, "missing name") unless args.name
    Puzzles.update args.id, $set: name: args.name
    oplog "Renamed puzzle: "+args.name, "puzzle", args.id
    # XXX: rename google drive folder
    # XXX: rename chat room logs?
    return true
  delPuzzle: (args) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    oplog "Deleted puzzle: "+Puzzles.findOne(args.id).name
    Puzzles.remove(args.id)
    # XXX: delete google drive folder
    # XXX: delete chat room logs?
    return true

  newNick: (args) ->
    throw new Meteor.Error(400, "missing name") unless args.name
    newNick =
      name: args.name or ""
      canon: canonical(args.name or "")
      tags: canonicalTags(args.tags or [])
    id = Nicks.insert newNick
    return Nicks.findOne(id)
  delNick: (args) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    Nicks.remove(args.id)
    return true

  newMessage: (args)->
    newMsg =
      body: args.body or ""
      nick: canonical(args.nick or "")
      system: args.system or false
      room_name: args.room_name or "general/0"
      timestamp: UTCNow()
    id = Messages.insert newMsg
    return Messages.findOne(id)

  setPresence: (args) ->
    throw new Meteor.Error(400, "missing nick") unless args.nick
    throw new Meteor.Error(400, "missing room") unless args.room_name
    newPresence =
      nick: canonical(args.nick)
      room_name: args.room_name
      timestamp: UTCNow()
      foreground: args.foreground or false
    existing = Presence.findOne
      nick: newPresence.nick
      room_name: newPresence.room_name
    if args.present
      # would be easier to use Mongo's "upsert" functionality, but
      # meteor doesn't support it
      if existing
        Presence.update
          nick: newPresence.nick
          room_name: newPresence.room_name
        ,
          $set:
            timestamp: newPresence.timestamp
            foreground: newPresence.foreground
      else
        Presence.insert newPresence
        Messages.insert
          system: true
          nick: ''
          body: args.nick + " joined the room."
          room_name: newPresence.room_name
          timestamp: newPresence.timestamp
    else
      Presence.remove
        nick: newPresence.nick
        room_name: newPresence.room_name
      if existing
        Messages.insert
          system: true
          nick: ''
          body: args.nick + " left the room."
          room_name: newPresence.room_name
          timestamp: newPresence.timestamp

  get: (type, id) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    return collection(type).findOne(id)

  setTag: (type, object, name, value) ->
    id = object._id or object
    canon = canonical(name)
    throw new Meteor.Error(400, "missing object") unless id
    throw new Meteor.Error(400, "missing name") unless name
    tags = collection(type).findOne(id).tags
    # remove existing value for tag, if present
    ntags = (tag for tag in tags when tag.canon isnt canon)
    # add new tag, but keep tags sorted
    ntags.push {name:name, canon:canon, value:value}
    ntags.sort (a, b) -> (a?.canon or "").localeCompare (b?.canon or "")
    # update the tag set only if there wasn't a race
    collection(type).update { _id: id, tags: tags }, { $set: { tags: ntags } }
    # XXX (on server) loop if this update failed?
    return true
  delTag: (type, object, name) ->
    id = object._id or object
    canon = canonical(name)
    throw new Meteor.Error(400, "missing object") unless id
    throw new Meteor.Error(400, "missing name") unless name
    tags = collection(type).findOne(id).tags
    ntags = (tag for tag in tags when tag.canon isnt canon)
    # update the tag set only if there wasn't a race
    collection(type).update { _id: id, tags: tags }, { $set: { tags: ntags } }
    # XXX (on server) loop if this update failed?
    return true

  addRoundToGroup: (round, group) ->
    # remove round from all other groups
    RoundGroups.find(rounds: round._id).forEach (rg) ->
      RoundGroups.update rg._id, $pull: rounds: round._id
    # add round to the given group
    RoundGroups.update group._id, $addToSet: rounds: round._id
    return true

  addPuzzleToRound: (puzzle, round) ->
    # remove puzzle from all other rounds
    Rounds.find(puzzles: puzzle._id).forEach (r) ->
      Rounds.update r._id, $pull: puzzles: puzzle._id
    # add puzzle to the given round
    Rounds.update round._id, $addToSet: puzzles: puzzle._id
    return true

  getRoundForPuzzle: (puzzle) ->
    id = puzzle._id or puzzle
    throw new Meteor.Error(400, "missing puzzle") unless id
    return Rounds.findOne(puzzles: id)

  getGroupForRound: (round) ->
    id = round._id or round
    throw new Meteor.Error(400, "missing round") unless id
    return RoundGroups.findOne(rounds: id)

  reorderPuzzle: (puzzle, args) ->
    id = puzzle._id or puzzle
    throw new Meteor.Error(400, "missing puzzle") unless id
    throw new Meteor.Error(400, "missing position") unless args.before or
                                                           args.after
    unimplemented()

  reorderRound: (round, args) ->
    id = round._id or round
    throw new Meteor.Error(400, "missing round") unless id
    throw new Meteor.Error(400, "missing position") unless args.before or
                                                           args.after
    unimplemented()

  setAnswer: (puzzle, answer, who="") ->
    id = puzzle._id or puzzle
    throw new Meteor.Error(400, "missing puzzle") unless id
    throw new Meteor.Error(400, "missing answer") unless answer
    now = UTCNow()
    Puzzles.update id, $set:
      answer: answer
      solved: now
      touched:now
      last_touch_by: who
    if Meteor.isClient
      blackboard.newAnswerSound.play()
    return true

  delAnswer: (puzzle, who="") ->
    id = puzzle._id or puzzle
    throw new Meteor.Error(400, "missing puzzle") unless id
    now = UTCNow()
    Puzzles.update id, $set:
      answer: null
      solved: null
      touched:now
      last_touch_by: who
    return true

  touch: (type, id, who) ->
   collection(type).update id, $set:
     touched: UTCNow()
     last_touch_by: who

  getChatLog: (type, id, from=0) ->
    # get LIMIT entries of chat log corresponding to type/id, starting
    # from (but not including) from timestamp, if nonzero
    # this allows us to page back in time by passing in the timestamp of
    # the earliest message from the previous call
    unimplemented()

UTCNow = ->
  now = new Date()
  #Date.UTC(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours(), now.getMinutes(), now.getSeconds(), now.getMilliseconds())
  return now.getTime()

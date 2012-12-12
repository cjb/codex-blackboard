# Blackboard -- data model
# Loaded on both the client and the server

# how often we send keep alive presence messages.  increase/decrease to adjust
# client/server load.
PRESENCE_KEEPALIVE_MINUTES = 2

BBCollection = Object.create(null) # create new object w/o any inherited cruft

# OpLogs are:
#   _id: mongodb id
#   timestamp: timestamp
#   message: string -- human-readable description of what was done
#   nick: canonicalized string -- who did it, if known
#   type: string
#   id: string -- type/id give a mongodb reference to the object modified
#                 so we can hyperlink to it.
OpLogs = BBCollection.oplogs = new Meteor.Collection "oplogs"

# RoundGroups are:
#   _id: mongodb id
#   name: string
#   canon: canonicalized version of name, for searching
#   created: timestamp (sort key)
#   created_by: _id of Nick
#   touched: timestamp -- records edits to tag, order, group, etc.
#   touched_by: _id of Nick with last touch
#   tags: [ { name: "Status", canon: "status", value: "stuck" }, ... ]
#   rounds: [ array of round _ids, in order ]
#   (next fields is a bit racy, oh well)
#   round_start: integer, indicating how many rounds total are in all
#                preceding round groups (a bit racy, but server fixes it up)
RoundGroups = BBCollection.roundgroups = new Meteor.Collection "roundgroups"
if Meteor.isServer
  RoundGroups._ensureIndex {canon: 1}, {unique:true, dropDups:true}
  # periodically go through and sync up round_start field
  Meteor.setInterval ->
    round_start = 0
    RoundGroups.find({}, sort: ["created"]).forEach (rg) ->
        if rg.round_start isnt round_start
          RoundGroups.update rg._id, $set: round_start: round_start
        round_start += rg.rounds.length
  , 60*1000

# Rounds are:
#   _id: mongodb id
#   name: string
#   canon: canonicalized version of name, for searching
#   created: timestamp
#   created_by: _id of Nick
#   touched: timestamp -- records edits to tag, order, group, etc.
#   touched_by: _id of Nick with last touch
#   tags: [ { name: "Status", canon: "status", value: "stuck" }, ... ]
#   puzzles: [ array of puzzle _ids, in order ]
#   drive: google drive url or id
Rounds = BBCollection.rounds = new Meteor.Collection "rounds"
if Meteor.isServer
  Rounds._ensureIndex {canon: 1}, {unique:true, dropDups:true}

# Puzzles are:
#   _id: mongodb id
#   name: string
#   canon: canonicalized version of name, for searching
#   answer: string (field is null (not missing or undefined) if not solved)
#   created: timestamp
#   created_by: _id of Nick
#   touched: timestamp
#   touched_by: _id of Nick with last touch
#   solved:  timestamp
#   solved_by:  timestamp of Nick who confirmed the answer
#   tags: [ { name: "Status", canon: "status", value: "stuck" }, ... ]
#   drive: google drive url or id
Puzzles = BBCollection.puzzles = new Meteor.Collection "puzzles"
if Meteor.isServer
   Puzzles._ensureIndex {canon: 1}, {unique:true, dropDups:true}

# Nicks are:
#   _id: mongodb id
#   name: string
#   canon: canonicalized version of name, for searching
#   tags: [ { name: "Real Name", canon: "real_name", value: "C. Scott Ananian" }, ... ]
# valid tags include "Real Name", "Gravatar" (email address to use for photos)
Nicks = BBCollection.nicks = new Meteor.Collection "nicks"
if Meteor.isServer
  Nicks._ensureIndex {canon: 1}, {unique:true, dropDups:true}

# Messages
#   body: string
#   nick: canonicalized string (may match some Nicks.canon ... or not)
#   system: boolean (true for system messages, false for user messages)
#   action: boolean (true for /me commands)
#   room_name: "<type>/<id>", ie "puzzle/1", "round/1". "general/0" for main chat.
#   timestamp: timestamp
Messages = BBCollection.messages = new Meteor.Collection "messages"
if Meteor.isServer
  Messages._ensureIndex {timestamp:-1}, {}

# Chat room presence
#   nick: canonicalized string, as in Messages
#   room_name: string, as in Messages
#   timestamp: timestamp -- when user was last seen in room
#   foreground: boolean (true if user's tab is still in foreground)
#   present: boolean (true if user is present, false if not)
Presence = BBCollection.presence = new Meteor.Collection "presence"
if Meteor.isServer
  Presence._ensureIndex {nick: 1, room_name:1}, {unique:true, dropDups:true}
  Presence._ensureIndex {timestamp:-1}, {}
  # ensure old entries are timed out after 2*PRESENCE_KEEPALIVE_MINUTES
  # some leeway here to account for client/server time drift
  Meteor.setInterval ->
    #console.log "Removing entries older than", (UTCNow() - 5*60*1000)
    removeBefore = UTCNow() - (2*PRESENCE_KEEPALIVE_MINUTES*60*1000)
    Presence.remove timestamp: $lt: removeBefore
  , 60*1000
  # generate automatic "<nick> entered <room>" and <nick> left room" messages
  # as the presence set changes
  Presence.remove {} # on server restart, begin with no presence
  Presence.find(present: true).observe
    added: (presence, beforeIndex) ->
      #console.log "#{presence.nick} entered #{presence.room_name}"
      Messages.insert
        system: true
        nick: ''
        body: presence.nick + " joined the room."
        room_name: presence.room_name
        timestamp: UTCNow()
    removed: (presence, atIndex) ->
      #console.log "#{presence.nick} left #{presence.room_name}"
      Messages.insert
        system: true
        nick: ''
        body: presence.nick + " left the room."
        room_name: presence.room_name
        timestamp: UTCNow()

# this reverses the name given to Meteor.Collection; that is the
# 'type' argument is the name of a server-side Mongo collection.
collection = (type) ->
  if Object::hasOwnProperty.call(BBCollection, type)
    BBCollection[type]
  else
    throw new Meteor.Error(400, "Bad collection type: "+type)

# pretty name for (one of) this collection
pretty_collection = (type) ->
  switch type
    when "oplogs" then "operation log"
    when "roundgroups" then "round group"
    else type.replace(/s$/, '')

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

(->
  # private helpers, not exported
  unimplemented = -> throw new Meteor.Error(500, "Unimplemented")

  canonicalTags = (tags) ->
    ({name:tag.name,canon:canonical(tag.name),value:tag.value} for tag in tags)

  oplog = (message, type="", id="", who="") ->
    OpLogs.insert
      timestamp: UTCNow()
      message: message
      type:type
      id:id
      nick: canonical(who)

  newObject = (type, args, extra, suppressLog=false) ->
    throw new Meteor.Error(400, "missing name") unless args.name
    throw new Meteor.Error(400, "missing who") unless args.who
    now = UTCNow()
    object =
      name: args.name
      canon: canonical(args.name) # for lookup
      created: now
      created_by: canonical(args.who)
      touched: now
      touched_by: canonical(args.who)
      tags: canonicalTags(args.tags or [])
    for own key,value of (extra or Object.create(null))
       object[key] = value
    object._id = collection(type).insert object
    unless suppressLog
      oplog "Added", type, object._id, args.who
    return object

  renameObject = (type, args, suppressLog=false) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    throw new Meteor.Error(400, "missing name") unless args.name
    throw new Meteor.Error(400, "missing who") unless args.who
    now = UTCNow()
    collection(type).update args.id, $set:
      name: args.name
      canon: canonical(args.name)
      touched: now
      touched_by: canonical(args.who)
    unless suppressLog
      oplog "Renamed", type, args.id, args.who
    return true

  deleteObject = (type, args, suppressLog=false) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    throw new Meteor.Error(400, "missing who") unless args.who
    name = collection(type)?.findOne(args.id)?.name
    return false unless name
    unless suppressLog
      oplog "Deleted "+pretty_collection(type)+" "+name, \
          type, null, args.who
    collection(type).remove(args.id)
    return true

  Meteor.methods
    newRoundGroup: (args) ->
      newObject "roundgroups", args,
        rounds: args.rounds or []
        round_start: Rounds.find({}).count() # approx; server will fix up
    renameRoundGroup: (args) ->
      renameObject "roundgroups", args
    deleteRoundGroup: (args) ->
      deleteObject "roundgroups", args

    newRound: (args) ->
      newObject "rounds", args,
        puzzles: args.puzzles or []
        drive: args.drive or null
    renameRound: (args) ->
      renameObject "rounds", args
    deleteRound: (args) ->
      r = deleteObject "rounds", args
      # XXX: delete google drive folder
      # XXX: delete chat room logs?
      return r

    newPuzzle: (args) ->
      p = newObject "puzzles", args,
        answer: null
        solved: null
        solved_by: null
        drive: args.drive or null
      # XXX: create google drive folder (server only)
      return p
    renamePuzzle: (args) ->
      r = renameObject "puzzles", args
      # XXX: rename google drive folder
      return r
    deletePuzzle: (args) ->
      r = deleteObject "puzzles", args
      # XXX: delete google drive folder
      # XXX: delete chat room logs?
      return r

    newNick: (args) ->
      # a bit of a stretch but let's reuse the object type
      newObject "nicks",
        name: args.name
        who: args.name
        tags: args.tags
      , {}, "suppressLog"
    renameNick: (args) ->
      renameObject "nicks", args, "suppressLog"
    deleteNick: (args) ->
       deleteObject "nicks", args, "suppressLog"

    newMessage: (args)->
      newMsg =
        body: args.body or ""
        nick: canonical(args.nick or "")
        system: args.system or false
        action: args.action or false
        room_name: args.room_name or "general/0"
        timestamp: UTCNow()
      newMsg._id = Messages.insert newMsg
      return newMsg

    setPresence: (args) ->
      throw new Meteor.Error(400, "missing nick") unless args.nick
      throw new Meteor.Error(400, "missing room") unless args.room_name
      return unless Meteor.isServer
      # we're going to do the db operation only on the server, so that we
      # can safely use mongo's 'upsert' functionality.  otherwise
      # Meteor seems to get a little confused as it creates presence
      # entries on the client that don't exist on the server.
      # (meteor does better when it's reconciling the *contents* of
      # documents, not their existence) (this is also why we added the
      # 'presence' field instead of deleting entries outright when
      # a user goes away)
      Presence.update
        nick: canonical(args.nick)
        room_name: args.room_name
      , $set:
          timestamp: UTCNow()
          foreground: args.foreground or false
          present: args.present or false
      , { upsert: true }

    get: (type, id) ->
      throw new Meteor.Error(400, "missing id") unless args.id
      return collection(type).findOne(id)

    setTag: (type, object, name, value, who) ->
      id = object._id or object
      throw new Meteor.Error(400, "missing object") unless id
      throw new Meteor.Error(400, "missing name") unless name
      throw new Meteor.Error(400, "missing who") unless who
      now = UTCNow()
      canon = canonical(name)
      tags = collection(type).findOne(id).tags
      # remove existing value for tag, if present
      ntags = (tag for tag in tags when tag.canon isnt canon)
      # add new tag, but keep tags sorted
      ntags.push
        name:name
        canon:canon
        value:value
        touched: now
        touched_by: canonical(who)
      ntags.sort (a, b) -> (a?.canon or "").localeCompare (b?.canon or "")
      # update the tag set only if there wasn't a race
      collection(type).update { _id: id, tags: tags }, $set:
        tags: ntags
        touched: now
        touched_by: canonical(who)
      # XXX (on server) loop if this update failed?
      return true
    deleteTag: (type, object, name, who) ->
      id = object._id or object
      throw new Meteor.Error(400, "missing object") unless id
      throw new Meteor.Error(400, "missing name") unless name
      throw new Meteor.Error(400, "missing who") unless who
      now = UTCNow()
      canon = canonical(name)
      tags = collection(type).findOne(id).tags
      ntags = (tag for tag in tags when tag.canon isnt canon)
      # update the tag set only if there wasn't a race
      collection(type).update { _id: id, tags: tags }, $set:
        tags: ntags
        touched: now
        touched_by: canonical(who)
      # XXX (on server) loop if this update failed?
      return true

    addRoundToGroup: (round, group, who) ->
      rid = round._id or round
      gid = group._id or group
      # remove round from all other groups
      RoundGroups.update { rounds: rid },{ $pull: rounds: rid },{ multi: true }
      # add round to the given group
      RoundGroups.update gid, $addToSet: rounds: rid
      return true

    addPuzzleToRound: (puzzle, round, who) ->
      pid = puzzle._id or puzzle
      rid = round._id or round
      # remove puzzle from all other rounds
      Rounds.update { puzzles: pid },{ $pull: puzzles: pid },{ multi: true }
      # add puzzle to the given round
      Rounds.update rid, $addToSet: puzzles: pid
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

    setAnswer: (puzzle, answer, who) ->
      id = puzzle._id or puzzle
      throw new Meteor.Error(400, "missing puzzle") unless id
      throw new Meteor.Error(400, "missing answer") unless answer
      throw new Meteor.Error(400, "missing who") unless who
      now = UTCNow()
      Puzzles.update id, $set:
        answer: answer
        solved: now
        solved_by: canonical(who)
        touched: now
        touched_by: canonical(who)
      oplog "Found an answer to", "puzzles", id, who
      return true

    deleteAnswer: (puzzle, who) ->
      id = puzzle._id or puzzle
      throw new Meteor.Error(400, "missing puzzle") unless id
      throw new Meteor.Error(400, "missing who") unless who
      now = UTCNow()
      Puzzles.update id, $set:
        answer: null
        solved: null
        solved_by: null
        touched: now
        touched_by: canonical(who)
      oplog "Deleted answer", "puzzles", id, who
      return true

    getChatLog: (type, id, from=0) ->
      # get LIMIT entries of chat log corresponding to type/id, starting
      # from (but not including) from timestamp, if nonzero
      # this allows us to page back in time by passing in the timestamp of
      # the earliest message from the previous call
      unimplemented()
)()

UTCNow = ->
  now = new Date()
  return now.getTime()

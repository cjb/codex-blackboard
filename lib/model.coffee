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
#   tags: [ { name: "status", value: "stuck" }, ... ]
RoundGroups = new Meteor.Collection "roundgroups"

# Rounds are:
#   _id: mongodb id
#   name: string (special name '' for puzzles w/o a round)
#   puzzles: [ array of puzzle _ids, in order ]
#   created: timestamp
#   touched: timestamp -- for special "round" chat, usually metapuzzle
#   last_touch_by: _id of Nick
#   tags: [ { name: "status", value: "stuck" }, ... ]
Rounds = new Meteor.Collection "rounds"

# Puzzles are:
#   _id: mongodb id
#   name: string
#   answer: string (field is null (not missing or undefined) if not solved)
#   created: timestamp
#   solved:  timestamp
#   touched: timestamp
#   last_touch_by: _id of Nick
#   tags: [ { name: "status", value: "stuck" }, ... ]
#   drive: google drive url or id
Puzzles = new Meteor.Collection "puzzles"

# Nicks are:
#   _id: mongodb id
#   name: string
#   tags: [ { name: "realname", value: "C. Scott Ananian" }, ... ]
Nicks = new Meteor.Collection "nicks"

# Messages
#   body: string
#   nick: string (may match entry in Nicks collection... or not)
#   system: boolean (true for system messages, false for user messages)
#   room_name: "<type>/<id>", ie "puzzle/1", "round/1". "codex" for main chat.
#   timestamp: timestamp
Messages = new Meteor.Collection "messages"

unimplemented = -> throw new Meteor.Error(500, "Unimplemented")
collection = (type) -> switch type
      when "puzzle" then Puzzles
      when "round" then Rounds
      when "roundgroup" then RoundGroups
      when "nick" then Nicks
      else throw new Meteor.Error(400, "Bad collection type")

oplog = (message, type="", id="") ->
  OpLogs.insert { timestamp:UTCNow(), message:message, type:type, id:id }

Meteor.methods
  newRoundGroup: (args) ->
    throw new Meteor.Error(400, "missing name") unless args.name
    newRoundGroup =
      name: args.name or ""
      tags: args.tags or []
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
    RoundGroups.delete(args.id)
    return true

  newRound: (args) ->
    throw new Meteor.Error(400, "missing name") unless args.name
    now = UTCNow()
    newRound =
      name: args.name or ""
      tags: args.tags or []
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
    Rounds.delete(args.id)
    # XXX: delete chat room logs?
    return true

  newPuzzle: (args) ->
    throw new Meteor.Error(400, "missing name") unless args.name
    now = UTCNow()
    newPuzzle =
      name: args.name or ""
      tags: args.tags or []
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
    Puzzles.delete(args.id)
    # XXX: delete google drive folder
    # XXX: delete chat room logs?
    return true

  newNick: (args) ->
    throw new Meteor.Error(400, "missing name") unless args.name
    newNick =
      name: args.name or ""
      tags: args.tags or []
    id = Nicks.insert newNick
    return Nicks.findOne(id)
  delNick: (args) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    Nicks.delete(args.id)
    return true

  newMessage: (args)->
    newMsg =
      body: args.body or ""
      nick: args.nick or ""
      system: args.system or false
      room_name: args.room_name or "general"
      timestamp: UTCNow()
    id = Messages.insert newMsg
    return Messages.findOne(id)

  get: (type, id) ->
    throw new Meteor.Error(400, "missing id") unless args.id
    return collection(type).findOne(id)

  setTag: (type, object, name, value) ->
    id = object._id or object
    throw new Meteor.Error(400, "missing object") unless id
    throw new Meteor.Error(400, "missing name") unless name
    collection(type).update id, $addToSet: tags: {name: name, value: value}
    return true
  delTag: (type, object, name) ->
    id = object._id or object
    throw new Meteor.Error(400, "missing object") unless id
    throw new Meteor.Error(400, "missing name") unless name
    tags = collection(type).findOne(id).tags
    ntags = tag for tag in tags when tag.name isnt name
    collection(type).update { _id: id, tags: tags }, { $set: { tags: ntags } }
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

  addAnswer: (puzzle, answer, who="") ->
    id = puzzle._id or puzzle
    throw new Meteor.Error(400, "missing puzzle") unless id
    throw new Meteor.Error(400, "missing answer") unless answer
    now = UTCNow()
    Puzzles.update id, $set:
      answer: answer
      solved: now
      touched:now
      last_touch_by: who
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
  Date.UTC(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours(), now.getMinutes(), now.getSeconds(), now.getMilliseconds())

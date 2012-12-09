# Blackboard -- data model
# Loaded on both the client and the server

# RoundGroups are:
#   _id: mongodb id
#   rounds: [ array of round _ids, in order ]
#   name: string (special name '' for rounds w/o a group)
#   tags: [ { name: "status", value: "stuck" }, ... ]
RoundGroups = new Meteor.Collection "roundgroups"

# Rounds are:
#   _id: mongodb id
#   puzzles: [ array of puzzle _ids, in order ]
#   name: string (special name '' for puzzles w/o a round)
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

Meteor.methods
  newNick: (args) ->
    newNick =
      name: args.name or "foo"
      tags: args.tags or []
    Nicks.insert newNick
    return true

  newMessage: (args)->
    newMsg =
      body: args.body or ""
      nick: args.nick or ""
      system: args.system or false
      room_name: args.room_name or "general"
      timestamp: UTCNow()
    Messages.insert newMsg
    return true

  addPuzzleToRound: (puzzle, round) ->
    # remove puzzle from all other rounds
    Rounds.find(puzzles: puzzle._id).forEach (r) ->
      Rounds.update r._id, $pull: puzzles: puzzle._id
    # add puzzle to the given round
    Rounds.update round._id, $addToSet: puzzles: puzzle._id
    return true

UTCNow = ->
  now = new Date()
  Date.UTC(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours(), now.getMinutes(), now.getSeconds(), now.getMilliseconds())

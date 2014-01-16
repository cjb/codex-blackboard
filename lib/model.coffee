'use strict'
# Blackboard -- data model
# Loaded on both the client and the server

# how often we send keep alive presence messages.  increase/decrease to adjust
# client/server load.
PRESENCE_KEEPALIVE_MINUTES = 2

# how many chats in a page?
MESSAGE_PAGE = 100

# this is used to yield "zero results" in collections which index by timestamp
NOT_A_TIMESTAMP = -9999

BBCollection = Object.create(null) # create new object w/o any inherited cruft

# Names is a synthetic collection created by the server which indexes
# the names and ids of RoundGroups, Rounds, and Puzzles:
#   _id: mongodb id (of a element in RoundGroups, Rounds, or Puzzles)
#   type: string ("roundgroups", "rounds", "puzzles")
#   name: string
#   canon: canonicalized version of name, for searching
Names = BBCollection.names = \
  if Meteor.isClient then new Meteor.Collection 'names' else null

# LastAnswer is a synthetic collection created by the server which gives the
# solution time of the most recently-solved puzzle.
#    _id: random UUID
#    solved: solution time
#    puzzle: id of most recently solved puzzle
LastAnswer = BBCollection.last_answer = \
  if Meteor.isClient then new Meteor.Collection 'last-answer' else null

# RoundGroups are:
#   _id: mongodb id
#   name: string
#   canon: canonicalized version of name, for searching
#   created: timestamp (sort key)
#   created_by: canon of Nick
#   touched: timestamp -- records edits to tag, order, group, etc.
#   touched_by: canon of Nick with last touch
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
#   created_by: canon of Nick
#   touched: timestamp -- records edits to tag, order, group, etc.
#   touched_by: canon of Nick with last touch
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
#   incorrectAnswers: [ { answer: "Wrong", who: "answer submitter",
#                         timestamp: ... }, ... ]
#   created: timestamp
#   created_by: canon of Nick
#   touched: timestamp
#   touched_by: canon of Nick with last touch
#   solved:  timestamp
#   solved_by:  timestamp of Nick who confirmed the answer
#   tags: [ { name: "Status", canon: "status", value: "stuck" }, ... ]
#   drive: google drive url or id
Puzzles = BBCollection.puzzles = new Meteor.Collection "puzzles"
if Meteor.isServer
  Puzzles._ensureIndex {canon: 1}, {unique:true, dropDups:true}

# CallIns are:
#   _id: mongodb id
#   puzzle: _id of Puzzle
#   answer: string (proposed answer to call in)
#   created: timestamp
#   created_by: canon of Nick
CallIns = BBCollection.callins = new Meteor.Collection "callins"
if Meteor.isServer
   CallIns._ensureIndex {created: 1}, {}
   CallIns._ensureIndex {puzzle: 1, answer: 1}, {unique:true, dropDups:true}

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
#   oplog:  boolean (true for semi-automatic operation log message)
#   to:   destination of pm (optional)
#   room_name: "<type>/<id>", ie "puzzle/1", "round/1".
#                             "general/0" for main chat.
#                             "oplog/0" for the operation log.
#   timestamp: timestamp
#
# Messages which are part of the operation log have `nick`, `message`,
# and `timestamp` set to describe what was done, when, and by who.
# They have `system=false`, `action=true`, `oplog=true`, `to=null`,
# and `room_name="oplog/0"`.  They also have two additional fields,
# `type` and `id`, which give a mongodb reference to the object
# modified so we can hyperlink to it.
Messages = BBCollection.messages = new Meteor.Collection "messages"
if Meteor.isServer
  Messages._ensureIndex {to:1, room_name:1, timestamp:-1}, {}
  Messages._ensureIndex {nick:1, room_name:1, timestamp:-1}, {}

# Pages -- paging metadata for Messages collection
#   from: timestamp (first page has from==0)
#   to: timestamp
#   room_name: corresponds to room_name in Messages collection.
#   prev: id of previous page for this room_name, or null
#   next: id of next page for this room_name, or null
# Messages with from <= timestamp < to are included in a specific page.
Pages = BBCollection.pages = new Meteor.Collection "pages"
if Meteor.isServer
  # used in the server observe code below
  Pages._ensureIndex {room_name:1, to:-1}, {unique:true}
  # used in the publish method
  Pages._ensureIndex {next: 1, room_name:1}, {}
  # watch messages collection and create pages as necessary
  do ->
    unpaged = Object.create(null)
    Messages.find({}, sort:[['timestamp','asc']]).observe
      added: (msg) ->
        room_name = msg.room_name
        # don't count pms (so we don't end up with a blank 'page')
        return if msg.to
        # add to (conservative) count of unpaged messages
        # (this message might already be in a page, but we'll catch that below)
        unpaged[room_name] = (unpaged[room_name] or 0) + 1
        return if unpaged[room_name] < MESSAGE_PAGE
        # recompute page parameters before adding a new page
        # (be safe in case we had out-of-order observations)
        # find highest existing page
        p = Pages.findOne({room_name: room_name}, {sort:[['to','desc']]})\
          or { _id: null, room_name: room_name, from: -1, to: 0 }
        # count the number of unpaged messages
        m = Messages.find(\
          {room_name: room_name, to: null, timestamp: $gte: p.to}, \
          {sort:[['timestamp','asc']], limit: MESSAGE_PAGE}).fetch()
        if m.length < MESSAGE_PAGE
          # false alarm: reset unpaged message count and continue
          unpaged[room_name] = m.length
          return
        # ok, let's make a new page.  this will include at least all the
        # messages in m, possibly more (if there are additional messages
        # added with timestamp == m[m.length-1].timestamp)
        pid = Pages.insert
          room_name: room_name
          from: p.to
          to: 1 + m[m.length-1].timestamp
          prev: p._id
          next: null
        if p._id?
          Pages.update p._id, $set: next: pid
        unpaged[room_name] = 0

# Last read message for a user in a particular chat room
#   nick: canonicalized string, as in Messages
#   room_name: string, as in Messages
#   timestamp: timestamp of last read message
LastRead = BBCollection.lastread = new Meteor.Collection "lastread"
if Meteor.isServer
  LastRead._ensureIndex {nick:1, room_name:1}, {unique:true, dropDups:true}
  LastRead._ensureIndex {nick:1}, {} # be safe

# Chat room presence
#   nick: canonicalized string, as in Messages
#   room_name: string, as in Messages
#   timestamp: timestamp -- when user was last seen in room
#   foreground: boolean (true if user's tab is still in foreground)
#   foreground_uuid: identity of client with tab in foreground
#   present: boolean (true if user is present, false if not)
Presence = BBCollection.presence = new Meteor.Collection "presence"
if Meteor.isServer
  Presence._ensureIndex {nick: 1, room_name:1}, {unique:true, dropDups:true}
  Presence._ensureIndex {timestamp:-1}, {}
  Presence._ensureIndex {present:1, room_name:1}, {}
  # ensure old entries are timed out after 2*PRESENCE_KEEPALIVE_MINUTES
  # some leeway here to account for client/server time drift
  Meteor.setInterval ->
    #console.log "Removing entries older than", (UTCNow() - 5*60*1000)
    removeBefore = UTCNow() - (2*PRESENCE_KEEPALIVE_MINUTES*60*1000)
    Presence.remove timestamp: $lt: removeBefore
  , 60*1000
  # generate automatic "<nick> entered <room>" and <nick> left room" messages
  # as the presence set changes
  initiallySuppressPresence = true
  Presence.find(present: true).observe
    added: (presence) ->
      return if initiallySuppressPresence
      # look up a real name, if there is one
      n = Nicks.findOne canon: canonical(presence.nick)
      name = getTag(n, 'Real Name') or presence.nick
      #console.log "#{name} entered #{presence.room_name}"
      return if presence.room_name is 'oplog/0'
      Messages.insert
        system: true
        nick: ''
        to: null
        body: "#{name} joined the room."
        room_name: presence.room_name
        timestamp: UTCNow()
    removed: (presence) ->
      return if initiallySuppressPresence
      # look up a real name, if there is one
      n = Nicks.findOne canon: canonical(presence.nick)
      name = getTag(n, 'Real Name') or presence.nick
      #console.log "#{name} left #{presence.room_name}"
      return if presence.room_name is 'oplog/0'
      Messages.insert
        system: true
        nick: ''
        to: null
        body: "#{name} left the room."
        room_name: presence.room_name
        timestamp: UTCNow()
  # turn on presence notifications once initial observation set has been
  # processed. (observe doesn't return on server until initial observation
  # is complete.)
  initiallySuppressPresence = false

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
  (tag.value for tag in (object?.tags or []) when tag.canon is canonical(name))[0]

# canonical names: lowercases, all non-alphanumerics replaced with '_'
canonical = (s) ->
  s = s.toLowerCase().replace(/^\s+/, '').replace(/\s+$/, '') # lower, strip
  # suppress 's and 't
  s = s.replace(/[\'\u2019]([st])\b/g, "$1")
  # replace all non-alphanumeric with _
  s = s.replace(/[^a-z0-9]+/g, '_').replace(/^_/,'').replace(/_$/,'')
  return s

drive_id_to_link = (id) ->
  "https://docs.google.com/folder/d/#{id}/edit"
spread_id_to_link = (id) ->
  "https://docs.google.com/spreadsheet/ccc?key=#{id}"

(->
  # private helpers, not exported
  unimplemented = -> throw new Meteor.Error(500, "Unimplemented")

  canonicalTags = (tags) ->
    check tags, [ObjectWith(name:NonEmptyString,value:Match.Any)]
    ({name:tag.name,canon:canonical(tag.name),value:tag.value} for tag in tags)

  NonEmptyString = Match.Where (x) ->
    check x, String
    return x.length > 0
  # a key of BBCollection
  ValidType = Match.Where (x) ->
    check x, NonEmptyString
    Object::hasOwnProperty.call(BBCollection, x)
  # either an id, or an object containing an id
  IdOrObject = Match.OneOf NonEmptyString, Match.Where (o) ->
    typeof o is 'object' and ((check o._id, NonEmptyString) or true)
  # This is like Match.ObjectIncluding, but we don't require `o` to be
  # a plain object
  ObjectWith = (pattern) ->
    Match.Where (o) ->
      return false if typeof(o) is not 'object'
      Object.keys(pattern).forEach (k) ->
        check o[k], pattern[k]
      true

  oplog = (message, type="", id="", who="") ->
    Messages.insert
      room_name: 'oplog/0'
      nick: canonical(who)
      timestamp: UTCNow()
      body: message
      type:type
      id:id
      oplog: true
      action: true
      system: false
      to: null

  newObject = (type, args, extra, options={}) ->
    check args, ObjectWith
      name: NonEmptyString
      who: NonEmptyString
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
    try
      object._id = collection(type).insert object
    catch error
      if Meteor.isServer and error?.name is 'MongoError' and error?.code==11000
        # duplicate key, fetch the real thing
        return collection(type).findOne({canon:canonical(args.name)})
      throw error # something went wrong, who knows what, pass it on
    unless options.suppressLog
      oplog "Added", type, object._id, args.who
    return object

  renameObject = (type, args, options={}) ->
    check args, ObjectWith
      id: NonEmptyString
      name: NonEmptyString
      who: NonEmptyString
    now = UTCNow()

    # Only perform the rename and oplog if the name is changing
    # XXX: This is racy with updates to findOne().name.
    if collection(type).findOne(args.id).name is args.name
      return false

    collection(type).update args.id, $set:
      name: args.name
      canon: canonical(args.name)
      touched: now
      touched_by: canonical(args.who)
    unless options.suppressLog
      oplog "Renamed", type, args.id, args.who
    return true

  deleteObject = (type, args, options={}) ->
    check type, ValidType
    check args, ObjectWith
      id: NonEmptyString
      who: NonEmptyString
    name = collection(type)?.findOne(args.id)?.name
    return false unless name
    unless options.suppressLog
      oplog "Deleted "+pretty_collection(type)+" "+name, \
          type, null, args.who
    collection(type).remove(args.id)
    return true

  newDriveFolder = (type, id, name) ->
    check type, NonEmptyString
    check id, NonEmptyString
    check name, NonEmptyString
    return unless Meteor.isServer
    res = share.drive.createPuzzle name
    return unless res?
    collection(type).update id, { $set:
      drive: res.id
      spreadsheet: res.spreadId
    }

  renameDriveFolder = (new_name, drive, spreadsheet) ->
    check new_name, NonEmptyString
    check drive, NonEmptyString
    check spreadsheet, Match.Optional(NonEmptyString)
    return unless Meteor.isServer
    share.drive.renamePuzzle(new_name, drive, spreadsheet)

  deleteDriveFolder = (drive) ->
    check drive, NonEmptyString
    return unless Meteor.isServer
    share.drive.deletePuzzle drive

  parentObject = do ->
    lookup =
      puzzles: (id) -> ['rounds', Rounds.findOne(puzzles: id)]
      rounds: (id) -> ['roundgroups', RoundGroups.findOne(rounds: id)]
      roundgroups: (id) -> [null, null]
    (type, id) -> lookup[type]?(id)

  moveObject = (type, id, direction) ->
    check type, NonEmptyString
    check id, NonEmptyString
    check direction, Match.Where (x) -> x=='up' or x=='down'

    adjSib = (type, id, dir, nonempty=true) ->
      sameLevel = true
      if type is 'roundgroups'
        parentType = parent = null
        sibs = RoundGroups.find({}, sort: ['created']).map (rg)->rg._id
      else
        [parentType, parent] = parentObject(type, id)
        sibs = parent[type]
      pos = sibs.indexOf(id)
      newPos = if dir is 'prev' then (pos-1) else (pos+1)
      if 0 <= newPos < sibs.length
        return [parentType, parent?._id, newPos, sibs[newPos], sameLevel]
      # otherwise, need to go up a level.
      upSibId = parent?._id
      sameLevel = false
      return [parentType, null, 0, null, sameLevel] unless upSibId
      loop
        [upType, upId, upPos, upSibId, _] = adjSib(parentType, upSibId, dir, true)
        return [parentType, null, 0, null, sameLevel] unless upSibId # no more sibs
        # check that this sibling has children (if nonempty is true)
        prevSibs = collection(parentType).findOne(upSibId)[type]
        newPos = if dir is 'prev' then (prevSibs.length - 1) else 0
        if 0 <= newPos < prevSibs.length
          return [parentType, upSibId, newPos, prevSibs[newPos], sameLevel]
        if prevSibs.length==0 and not nonempty
          return [parentType, upSibId, 0, null, sameLevel]
        # crap, adjacent parent has no children, need *next* parent (loop)

    dir = if direction is 'up' then 'prev' else 'next'
    [parentType,newParent,newPos,adjId,sameLevel] = adjSib(type,id,dir,false)
    args = if (direction is 'up') is sameLevel then {before:adjId} else {after:adjId}
    # now do the move.  note that there are races, in that we're not guaranteed
    # some other concurrent re-ordering/insertions haven't made this the
    # 'wrong' place to insert --- but we *are* going to insert it *somewhere*
    # regardless.  Hopefully the user will notice and forgive us if the
    # object ends up slightly out of place.
    switch type
      when 'puzzles'
        return false unless newParent # can't go further in this direction
        [args.puzzle, args.round] = [id, newParent]
        Meteor.call 'addPuzzleToRound', args
      when 'rounds'
        return false unless newParent # can't go further in this direction
        [args.round, args.group] = [id, newParent]
        Meteor.call 'addRoundToGroup', args
      when 'roundgroups'
        return false unless adjId # can't go further in this direction
        # this is a bit of a hack!
        thisGroup = RoundGroups.findOne(id)
        thatGroup = RoundGroups.findOne(adjId)
        # swap creation times! (i told you this was a hack)
        [thisCreated,thatCreated] = [thisGroup.created, thatGroup.created]
        RoundGroups.update thisGroup._id, $set: created: thatCreated
        RoundGroups.update thatGroup._id, $set: created: thisCreated
        return true # it's a hack and we know it, clap your hands
      else
        throw new Meteor.Error(400, "bad type: #{type}")

  Meteor.methods
    newRoundGroup: (args) ->
      newObject "roundgroups", args,
        rounds: args.rounds or []
        round_start: Rounds.find({}).count() # approx; server will fix up
    renameRoundGroup: (args) ->
      renameObject "roundgroups", args
    deleteRoundGroup: (args) ->
      check args, ObjectWith
        id: NonEmptyString
        who: NonEmptyString
      # disallow deletion unless roundgroup.rounds is empty
      # XXX or else move rounds to some other group(s)
      rg = RoundGroups.findOne(args.id)
      return false unless rg? and rg?.rounds?.length is 0
      deleteObject "roundgroups", args

    newRound: (args) ->
      r = newObject "rounds", args,
        puzzles: args.puzzles or []
        drive: args.drive or null
      newDriveFolder "rounds", r._id, r.name
      return r
    renameRound: (args) ->
      check args, ObjectWith
        id: NonEmptyString
        name: NonEmptyString
        who: NonEmptyString
      # get drive ID (racy)
      r = Rounds.findOne(args.id)
      drive = r?.drive
      spreadsheet = r?.spreadsheet
      result = renameObject "rounds", args
      # rename google drive folder
      renameDriveFolder args.name, drive, spreadsheet if (result and drive?)
      return result
    deleteRound: (args) ->
      check args, ObjectWith
        id: NonEmptyString
        who: NonEmptyString
      rid = args.id
      old = Rounds.findOne(rid)
      # disallow deletion unless round.puzzles is empty
      # XXX or else move puzzles to some other round(s)
      return false unless old? and old?.puzzles?.length is 0
      # get drive ID (racy)
      drive = old?.drive
      spreadsheet = old?.spreadsheet
      # remove round itself
      r = deleteObject "rounds", args
      # remove from all roundgroups
      RoundGroups.update { rounds: rid },{ $pull: rounds: rid },{ multi: true }
      # delete google drive folder and all contents, recursively
      deleteDriveFolder drive, spreadsheet if drive?
      # XXX: delete chat room logs?
      return r

    newPuzzle: (args) ->
      p = newObject "puzzles", args,
        answer: null
        incorrectAnswers: []
        solved: null
        solved_by: null
        drive: args.drive or null
        spreadsheet: args.spreadsheet or null
      # create google drive folder (server only)
      newDriveFolder "puzzles", p._id, p.name
      return p
    renamePuzzle: (args) ->
      check args, ObjectWith
        id: NonEmptyString
        name: NonEmptyString
        who: NonEmptyString
      # get drive ID (racy)
      p = Puzzles.findOne(args.id)
      drive = p?.drive
      spreadsheet = p?.spreadsheet
      result = renameObject "puzzles", args
      # rename google drive folder
      renameDriveFolder args.name, drive, spreadsheet if (result and drive?)
      return result
    deletePuzzle: (args) ->
      check args, ObjectWith
        id: NonEmptyString
        who: NonEmptyString
      pid = args.id
      # get drive ID (racy)
      old = Puzzles.findOne(args.id)
      drive = old?.drive
      spreadsheet = old?.spreadsheet
      # remove puzzle itself
      r = deleteObject "puzzles", args
      # remove from all rounds
      Rounds.update { puzzles: pid },{ $pull: puzzles: pid },{ multi: true }
      # delete google drive folder
      deleteDriveFolder drive, spreadsheet if drive?
      # XXX: delete chat room logs?
      return r

    newCallIn: (args) ->
      check args, ObjectWith
        puzzle: IdOrObject
        answer: NonEmptyString
        who: NonEmptyString
      id = args.puzzle._id or args.puzzle
      newObject "callins", {name:canonical(args.answer), who:args.who},
        puzzle: id
        answer: args.answer
        who: args.who
      , {suppressLog:true}
      oplog "New answer #{args.answer} submitted for", "puzzles", id, args.who

    correctCallIn: (args) ->
      check args, ObjectWith
        id: NonEmptyString
        who: NonEmptyString
      callin = CallIns.findOne(args.id)
      throw new Meteor.Error(400, "bad callin") unless callin
      # call-in is cancelled as a side-effect of setAnswer
      Meteor.call "setAnswer",
        puzzle: callin.puzzle
        answer: callin.answer
        who: args.who

    incorrectCallIn: (args) ->
      check args, ObjectWith
        id: NonEmptyString
        who: NonEmptyString
      callin = CallIns.findOne(args.id)
      throw new Meteor.Error(400, "bad callin") unless callin
      # call-in is cancelled as a side-effect of addIncorrectAnswer
      Meteor.call "addIncorrectAnswer",
        puzzle: callin.puzzle
        answer: callin.answer
        who: args.who

    cancelCallIn: (args) ->
      check args, ObjectWith
        id: NonEmptyString
        who: NonEmptyString
        suppressLog: Match.Optional(Boolean)
      callin = CallIns.findOne(args.id)
      throw new Meteor.Error(400, "bad callin") unless callin
      unless args.suppressLog
        oplog "Canceled call-in of #{callin.answer} for", "puzzles", callin.puzzle, args.who
      deleteObject "callins",
        id: args.id
        who: args.who
      , {suppressLog:true}

    newNick: (args) ->
      check args, ObjectWith
        name: NonEmptyString
      # a bit of a stretch but let's reuse the object type
      newObject "nicks",
        name: args.name
        who: args.name
        tags: canonicalTags(args.tags or [])
      , {}, {suppressLog:true}
    renameNick: (args) ->
      renameObject "nicks", args, {suppressLog:true}
    deleteNick: (args) ->
      deleteObject "nicks", args, {suppressLog:true}

    newMessage: (args) ->
      check args, Object
      return if this.isSimulation # suppress flicker
      newMsg =
        body: args.body or ""
        bodyIsHtml: args.bodyIsHtml or false
        nick: canonical(args.nick or "")
        system: args.system or false
        action: args.action or false
        to: canonical(args.to or "") or null
        room_name: args.room_name or "general/0"
        timestamp: UTCNow()
      # update the user's 'last read' message to include this one
      # (doing it here allows us to use server timestamp on message)
      unless (args.suppressLastRead or newMsg.system or (not newMsg.nick))
        Meteor.call 'updateLastRead',
          nick: newMsg.nick
          room_name: newMsg.room_name
          timestamp: newMsg.timestamp
      newMsg._id = Messages.insert newMsg
      return newMsg

    updateLastRead: (args) ->
      check args, ObjectWith
        nick: NonEmptyString
        room_name: NonEmptyString
        timestamp: Number
      try
        LastRead.upsert
          nick: canonical(args.nick)
          room_name: args.room_name
          timestamp: $lt: args.timestamp
        , $set:
          timestamp: args.timestamp
      catch e
        # ignore duplicate key errors; they are harmless and occur when we
        # try to move the LastRead.timestamp backwards.
        if Meteor.isServer and e?.name is 'MongoError' and e?.code==11000
          return false
        throw e

    setPresence: (args) ->
      check args, ObjectWith
        nick: NonEmptyString
        room_name: NonEmptyString
      # we're going to do the db operation only on the server, so that we
      # can safely use mongo's 'upsert' functionality.  otherwise
      # Meteor seems to get a little confused as it creates presence
      # entries on the client that don't exist on the server.
      # (meteor does better when it's reconciling the *contents* of
      # documents, not their existence) (this is also why we added the
      # 'presence' field instead of deleting entries outright when
      # a user goes away)
      # IN METEOR 0.6.6 upsert support was added to the client.  So let's
      # try to do this on both sides now.
      #return unless Meteor.isServer
      Presence.upsert
        nick: canonical(args.nick)
        room_name: args.room_name
      , $set:
          timestamp: UTCNow()
          present: args.present or false
      return unless args.present
      # only set foreground if true or foreground_uuid matches; this
      # prevents bouncing if user has two tabs open, and one is foregrounded
      # and the other is not.
      if args.foreground
        Presence.update
          nick: canonical(args.nick)
          room_name: args.room_name
        , $set:
          foreground: true
          foreground_uuid: args.uuid
      else # only update 'foreground' if uuid matches
        Presence.update
          nick: canonical(args.nick)
          room_name: args.room_name
          foreground_uuid: args.uuid
        , $set:
          foreground: args.foreground or false
      return

    get: (type, id) ->
      check type, NonEmptyString
      check id, NonEmptyString
      return collection(type).findOne(id)

    getByName: (args) ->
      check args, ObjectWith
        name: NonEmptyString
        optional_type: Match.Optional(NonEmptyString)
      for type in ['roundgroups','rounds','puzzles','nicks']
        continue if args.optional_type and args.optional_type isnt type
        o = collection(type).findOne canon: canonical(args.name)
        return {type:type,object:o} if o
      return null # no match found

    setField: (type, object, fields, who) ->
      check type, ValidType
      check object, IdOrObject
      check fields, Object
      check who, NonEmptyString
      id = object._id or object
      now = UTCNow()
      # disallow modifications to the following fields; use other APIs for these
      for f in ['name','canon','created','created_by','solved','solved_by',
               'tags','rounds','round_start','puzzles']
        delete fields[f]
      fields.touched = now
      fields.touched_by = canonical(who)
      collection(type).update id, $set: fields
      return true

    setTag: (type, object, name, value, who) ->
      check type, ValidType
      check object, IdOrObject
      check name, NonEmptyString
      check who, NonEmptyString
      check value, Match.Any
      id = object._id or object
      now = UTCNow()
      canon = canonical(name)
      loop
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
        numchanged = collection(type).update { _id: id, tags: tags }, $set:
          tags: ntags
          touched: now
          touched_by: canonical(who)
        # try again if this update failed due to a race (server only)
        break unless Meteor.isServer and numchanged is 0
      return true
    deleteTag: (type, object, name, who) ->
      check type, ValidType
      check object, IdOrObject
      check name, NonEmptyString
      check who, NonEmptyString
      id = object._id or object
      now = UTCNow()
      canon = canonical(name)
      loop
        tags = collection(type).findOne(id).tags
        ntags = (tag for tag in tags when tag.canon isnt canon)
        # update the tag set only if there wasn't a race
        numchanged = collection(type).update { _id: id, tags: tags }, $set:
          tags: ntags
          touched: now
          touched_by: canonical(who)
        # try again if this update failed due to a race (server only)
        break unless Meteor.isServer and numchanged is 0
      return true

    addRoundToGroup: (args) ->
      check args, ObjectWith
        round: IdOrObject
        group: IdOrObject
      rid = args.round._id or args.round
      gid = args.group._id or args.group
      rg = RoundGroups.findOne(gid)
      throw new Meteor.Error(400, "bad group") unless rg
      # remove round from all other groups
      RoundGroups.update { rounds: rid },{ $pull: rounds: rid },{ multi: true }
      # add round to the given group
      if args.before or args.after
        # add to a specific location
        rounds = (r for r in rg.rounds when r != rid)
        nrounds = rounds[..]
        if args.before
          npos = rounds.indexOf(args.before)
        else
          npos = rounds.indexOf(args.after) + 1
        nrounds.splice(npos, 0, rid)
        # update the collection only if there wasn't a race
        RoundGroups.update {_id: gid, rounds: rounds}, $set: rounds: nrounds
      # add to the end (no-op if the 'at' clause succeeded)
      RoundGroups.update gid, $addToSet: rounds: rid
      return true

    addPuzzleToRound: (args) ->
      check args, ObjectWith
        puzzle: IdOrObject
        round: IdOrObject
      pid = args.puzzle._id or args.puzzle
      rid = args.round._id or args.round
      check rid, NonEmptyString
      r = Rounds.findOne(rid)
      throw new Meteor.Error(400, "bad round") unless r
      # remove puzzle from all other rounds
      Rounds.update { puzzles: pid },{ $pull: puzzles: pid },{ multi: true }
      # add puzzle to the given round
      if args.before or args.after
        # add to a specific location
        puzzles = (p for p in r.puzzles when p != pid)
        npuzzles = puzzles[..]
        if puzzles.length == 0
          npos = 0
        else if args.before
          npos = puzzles.indexOf(args.before)
        else
          npos = puzzles.indexOf(args.after) + 1
        npuzzles.splice(npos, 0, pid)
        # update the collection only if there wasn't a race
        Rounds.update {_id: rid, puzzles: puzzles}, $set: puzzles: npuzzles
      # add to the end (no-op if the 'at' clause succeeded)
      Rounds.update rid, $addToSet: puzzles: pid
      return true

    getRoundForPuzzle: (puzzle) ->
      check puzzle, IdOrObject
      id = puzzle._id or puzzle
      check id, NonEmptyString
      return Rounds.findOne(puzzles: id)

    getGroupForRound: (round) ->
      check round, IdOrObject
      id = round._id or round
      return RoundGroups.findOne(rounds: id)

    moveUp: (args) -> moveObject(args.type, args.id, "up")

    moveDown: (args) -> moveObject(args.type, args.id, "down")

    setAnswer: (args) ->
      check args, ObjectWith
        puzzle: IdOrObject
        answer: NonEmptyString
        who: NonEmptyString
      id = args.puzzle._id or args.puzzle
      now = UTCNow()

      # Only perform the update and oplog if the answer is changing
      # XXX: This is racy with updates to findOne().answer.
      if Puzzles.findOne(id).answer is args.answer
        return false

      Puzzles.update id, $set:
        answer: args.answer
        solved: now
        solved_by: canonical(args.who)
        touched: now
        touched_by: canonical(args.who)
      oplog "Found an answer to", "puzzles", id, args.who
      # cancel any entries on the call-in queue for this puzzle
      for c in CallIns.find(puzzle: id).fetch()
        Meteor.call 'cancelCallIn',
          id: c._id
          who: args.who
          suppressLog: (c.answer is args.answer)
      return true

    addIncorrectAnswer: (args) ->
      check args, ObjectWith
        puzzle: IdOrObject
        answer: NonEmptyString
        who: NonEmptyString
      id = args.puzzle._id or args.puzzle
      now = UTCNow()

      puzzle = Puzzles.findOne(id)
      throw new Meteor.Error(400, "bad puzzle") unless puzzle
      Puzzles.update id, $push:
         incorrectAnswers:
          answer: args.answer
          timestamp: UTCNow()
          who: args.who

      oplog "Incorrect answer #{args.answer} for", "puzzles", id, args.who
      # cancel any matching entries on the call-in queue for this puzzle
      for c in CallIns.find(puzzle: id, answer: args.answer).fetch()
        Meteor.call 'cancelCallIn',
          id: c._id
          who: args.who
          suppressLog: true
      return true

    deleteAnswer: (args) ->
      check args, ObjectWith
        puzzle: IdOrObject
        who: NonEmptyString
      id = args.puzzle._id or args.puzzle
      now = UTCNow()
      Puzzles.update id, $set:
        answer: null
        solved: null
        solved_by: null
        touched: now
        touched_by: canonical(args.who)
      oplog "Deleted answer for", "puzzles", id, args.who
      return true

    getRinghuntersFolder: ->
      return unless Meteor.isServer
      # Return special folder used for uploads to general Ringhunters chat
      return share.drive.ringhuntersFolder
)()

UTCNow = ->
  now = new Date()
  return now.getTime()

# exports
share.model =
  # constants
  PRESENCE_KEEPALIVE_MINUTES: PRESENCE_KEEPALIVE_MINUTES
  MESSAGE_PAGE: MESSAGE_PAGE
  NOT_A_TIMESTAMP: NOT_A_TIMESTAMP
  # collection types
  CallIns: CallIns
  Names: Names
  LastAnswer: LastAnswer
  RoundGroups: RoundGroups
  Rounds: Rounds
  Puzzles: Puzzles
  Nicks: Nicks
  Messages: Messages
  Pages: Pages
  LastRead: LastRead
  Presence: Presence
  # helper methods
  collection: collection
  pretty_collection: pretty_collection
  getTag: getTag
  canonical: canonical
  drive_id_to_link: drive_id_to_link
  spread_id_to_link: spread_id_to_link
  UTCNow: UTCNow

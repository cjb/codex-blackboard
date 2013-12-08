# Blackboard -- data model
# Loaded on both the client and the server

# how often we send keep alive presence messages.  increase/decrease to adjust
# client/server load.
PRESENCE_KEEPALIVE_MINUTES = 2

# URL for google-drive python server
GDRIVE_HOST = 'http://hydro.laptop.org:5000'

# Hard-coded URL for special folder used for Ringhunters chat.
RINGHUNTERS_FOLDER = '0Bx954IXk0MK_bV9lQzZCMXpnLXM'

# how many chats in a page?
MESSAGE_PAGE = 150
# how many oplogs in a page?
OPLOG_PAGE = 150

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
#   to:   destination of pm (optional)
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
#   foreground_uuid: identity of client with tab in foreground
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
  initiallySuppressPresence = true
  Presence.find(present: true).observe
    added: (presence) ->
      return if initiallySuppressPresence
      # look up a real name, if there is one
      n = Nicks.findOne canon: canonical(presence.nick)
      name = getTag(n, 'Real Name') or presence.nick
      #console.log "#{name} entered #{presence.room_name}"
      Messages.insert
        system: true
        nick: ''
        body: "#{name} joined the room."
        room_name: presence.room_name
        timestamp: UTCNow()
    removed: (presence) ->
      return if initiallySuppressPresence
      # look up a real name, if there is one
      n = Nicks.findOne canon: canonical(presence.nick)
      name = getTag(n, 'Real Name') or presence.nick
      #console.log "#{name} left #{presence.room_name}"
      Messages.insert
        system: true
        nick: ''
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
    ({name:tag.name,canon:canonical(tag.name),value:tag.value} for tag in tags)

  oplog = (message, type="", id="", who="") ->
    OpLogs.insert
      timestamp: UTCNow()
      message: message
      type:type
      id:id
      nick: canonical(who)

  newObject = (type, args, extra, options={}) ->
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
    throw new Meteor.Error(400, "missing id") unless args.id
    throw new Meteor.Error(400, "missing name") unless args.name
    throw new Meteor.Error(400, "missing who") unless args.who
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
    throw new Meteor.Error(400, "missing id") unless args.id
    throw new Meteor.Error(400, "missing who") unless args.who
    name = collection(type)?.findOne(args.id)?.name
    return false unless name
    unless options.suppressLog
      oplog "Deleted "+pretty_collection(type)+" "+name, \
          type, null, args.who
    collection(type).remove(args.id)
    return true

  newDriveFolder = (type, id, name) ->
    return unless Meteor.isServer
    Meteor.http.post "#{GDRIVE_HOST}/puzzle/Codex: #{name}", (err, res) ->
      if err
        console.log "Error creating folder on Google Drive: ", err
      else if res?.data
        collection(type).update id, { $set:
          drive: res.data.id
          spreadsheet: res.data.spread_id
        }
      else
        console.log "Some other error creating folder: ", data
  renameDriveFolder = (drive, new_name) ->
    return unless Meteor.isServer
    Meteor.http.call "MOVE", "#{GDRIVE_HOST}/puzzle/#{drive}/Codex: #{new_name}", (err, res) ->
      if err
        console.log "Error renaming folder on Google Drive: ", err
  deleteDriveFolder = (drive, spread_id=null) ->
    return unless Meteor.isServer
    if spread_id
      Meteor.http.del "#{GDRIVE_HOST}/puzzle/#{spread_id}", (err, res) ->
        console.log "Error deleting spreadsheet on Google Drive: #{err}" if err
    Meteor.http.del "#{GDRIVE_HOST}/puzzle/#{drive}", (err, res) ->
      if err
        console.log "Error deleting folder on Google Drive: ", err

  parentObject = do ->
    lookup =
      puzzles: (id) -> ['rounds', Rounds.findOne(puzzles: id)]
      rounds: (id) -> ['roundgroups', RoundGroups.findOne(rounds: id)]
      roundgroups: (id) -> [null, null]
    (type, id) -> lookup[type]?(id)

  moveObject = (type, id, direction) ->
    throw new Meteor.Error(400, "missing type") unless type
    throw new Meteor.Error(400, "missing id") unless id

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
      # XXX disallow deletion unless roundgroup.rounds is empty?
      # XXX or else move rounds to some other group(s)
      deleteObject "roundgroups", args

    newRound: (args) ->
      r = newObject "rounds", args,
        puzzles: args.puzzles or []
        drive: args.drive or null
      newDriveFolder "rounds", r._id, r.name
      return r
    renameRound: (args) ->
      # get drive ID (racy)
      drive = Rounds.findOne(args.id)?.drive
      result = renameObject "rounds", args
      # rename google drive folder
      renameDriveFolder drive, args.name if (result and drive)
      return result
    deleteRound: (args) ->
      rid = args.id
      # get drive ID (racy)
      old = Rounds.findOne(args.id)
      drive = old?.drive
      spread_id = old?.spread_id
      # XXX disallow deletion unless round.puzzles is empty?
      # XXX or else move puzzles to some other round(s)
      # remove round itself
      r = deleteObject "rounds", args
      # remove from all roundgroups
      RoundGroups.update { rounds: rid },{ $pull: rounds: rid },{ multi: true }
      # delete google drive folder
      deleteDriveFolder drive, spread_id if drive
      # XXX: delete chat room logs?
      return r

    newPuzzle: (args) ->
      p = newObject "puzzles", args,
        answer: null
        solved: null
        solved_by: null
        drive: args.drive or null
        spreadsheet: args.spreadsheet or null
      # create google drive folder (server only)
      newDriveFolder "puzzles", p._id, p.name
      return p

    renamePuzzle: (args) ->
      # get drive ID (racy)
      drive = Puzzles.findOne(args.id)?.drive
      result = renameObject "puzzles", args
      # rename google drive folder
      renameDriveFolder drive, args.name if (result and drive)
      return result

    deletePuzzle: (args) ->
      pid = args.id
      # get drive ID (racy)
      old = Puzzles.findOne(args.id)
      drive = old?.drive
      spread_id = old?.spread_id
      # remove puzzle itself
      r = deleteObject "puzzles", args
      # remove from all rounds
      Rounds.update { puzzles: pid },{ $pull: puzzles: pid },{ multi: true }
      # delete google drive folder
      deleteDriveFolder drive, spread_id if drive
      # XXX: delete chat room logs?
      return r

    newNick: (args) ->
      # a bit of a stretch but let's reuse the object type
      newObject "nicks",
        name: args.name
        who: args.name
        tags: args.tags
      , {}, {suppressLog:true}
    renameNick: (args) ->
      renameObject "nicks", args, {suppressLog:true}
    deleteNick: (args) ->
       deleteObject "nicks", args, {suppressLog:true}

    newMessage: (args)->
      newMsg =
        body: args.body or ""
        bodyIsHtml: args.bodyIsHtml or false
        nick: canonical(args.nick or "")
        system: args.system or false
        action: args.action or false
        to: canonical(args.to or "") or null
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
          present: args.present or false
      , { upsert: true }
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
      throw new Meteor.Error(400, "missing id") unless args.id
      return collection(type).findOne(id)

    getByName: (args) ->
      for type in ['roundgroups','rounds','puzzles','nicks']
        continue if args.optional_type and args.optional_type isnt type
        o = collection(type).findOne canon: canonical(args.name)
        return {type:type,object:o} if o
      return null # no match found

    setField: (type, object, fields, who) ->
      id = object._id or object
      throw new Meteor.Error(400, "missing id") unless id
      throw new Meteor.Error(400, "missing who") unless args.who
      throw new Meteor.Error(400, "bad fields") unless typeof(fields)=='object'
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

    addRoundToGroup: (args) ->
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
      pid = args.puzzle._id or args.puzzle
      rid = args.round._id or args.round
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
      id = puzzle._id or puzzle
      throw new Meteor.Error(400, "missing puzzle") unless id
      return Rounds.findOne(puzzles: id)

    getGroupForRound: (round) ->
      id = round._id or round
      throw new Meteor.Error(400, "missing round") unless id
      return RoundGroups.findOne(rounds: id)

    moveUp: (args) -> moveObject(args.type, args.id, "up")

    moveDown: (args) -> moveObject(args.type, args.id, "down")

    setAnswer: (args) ->
      id = args.puzzle._id or args.puzzle
      throw new Meteor.Error(400, "missing puzzle") unless id
      throw new Meteor.Error(400, "missing answer") unless args.answer
      throw new Meteor.Error(400, "missing who") unless args.who
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
      return true

    deleteAnswer: (args) ->
      id = args.puzzle._id or args.puzzle
      throw new Meteor.Error(400, "missing puzzle") unless id
      throw new Meteor.Error(400, "missing who") unless args.who
      now = UTCNow()
      Puzzles.update id, $set:
        answer: null
        solved: null
        solved_by: null
        touched: now
        touched_by: canonical(args.who)
      oplog "Deleted answer for", "puzzles", id, args.who
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

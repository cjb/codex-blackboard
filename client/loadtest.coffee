# sample data for load testing
ensureData = (cb) ->
  who = 'loadtest'
  Meteor.call 'newRoundGroup',
    name: 'roundgroup',
    who: who,
    rounds: null
  , (err, rg) ->
    cb(err) if err?
    Meteor.call 'newRound',
      name: 'round'
      who: who
      puzzles: null
    , (err, r) ->
      cb(err) if err?
      Meteor.call 'addRoundToGroup', {round:r, group:rg, who:who}
      Meteor.call 'newPuzzle',
        name: 'puzzle'
        who: 'loadtest'
      , (err, p) ->
        cb(err) if err?
        Meteor.call 'addPuzzleToRound', {puzzle:p, round:r, who:who}
        cb null,
          puzzle: p
          round: r
          roundgroup: rg

# different load testing tasks
tasks = Object.create(null)
totalProb = 0
addTask = (name, f, prob=1) ->
  tasks[name] =
    name: name,
    func: f,
    p: {start: totalProb, end: totalProb + prob}
  totalProb = tasks[name].p.end

# pick a random nick
randomNick = ->
  Random.choice [
    'alice','bob','charlie','del','eve','frank','georgia','mallory','tom','zeke'
  ]

# login
login = (nick=randomNick()) ->
  $.cookie 'nick', nick, {expires:365, path: '/'}
  Session.set 'nick', nick
  Meteor.call 'newNick', {name:nick}

# say something every 10s or so
saySomething = (room_name) ->
  Meteor.setTimeout saySomething.bind(null, room_name), \
    (5 + 10*Random.fraction()) * 1000 # 5-15 seconds
  who = Session.get('nick') or 'loadtest'
  friend = randomNick()
  m = switch Random.choice ['system','action','pm','text','text','text']
    when 'system'
      system: true
      body: "system message from #{who}"
      nick: ''
    when 'action'
      nick: who
      body: Random.choice [
        "does something nice for #{friend}",
        "has a crush on #{friend}",
        "steps away from the keyboard",
        "solves a puzzle",
      ]
      action: true
    when 'pm'
      nick: who
      to: friend
      body: Random.choice [
        "Isn't #{randomNick()} totally hot?",
        "Do you think this answer could be right?",
        "This puzzle is hard!",
      ]
    when 'text'
      nick: who
      body: Random.choice [
        "I don't care who knows it --- I love #{friend}!!!",
        "I think we're finally getting someplace with this puzzle",
        "Are we going to win the hunt?",
        "Me, too!"
      ]
  m.room_name = room_name
  Meteor.call 'newMessage', m

# add puzzles and rounds every 20s
addPuzzles = (data) ->
  Meteor.setTimeout addPuzzles.bind(null, data),
    (15 + 10*Random.fraction()) * 1000 # 15-25 seconds
  [who,name] = [Session.get('nick'), Random.hexString(16)]
  [followup,removeit] = [null,null]
  cb = (err,o) ->
    return if err?
    followup o, ->
      Meteor.setTimeout((-> removeit(o)), 10*1000)
  switch Random.choice ['roundgroup', 'round', 'puzzle']
    when 'roundgroup'
      followup = (rg, cb) ->
        Meteor.call 'renameRoundGroup',
          id: rg._id
          name: Random.hexString(16)
          who:who
        , cb
      removeit = (rg) ->
        Meteor.call 'deleteRoundGroup',
          id: rg._id
          who: who
      Meteor.call 'newRoundGroup', {name:name,who:who,rounds:null}, cb
    when 'round'
      followup = (r, cb) ->
        Meteor.call 'addRoundToGroup',
          round: r._id
          group: data.roundgroup._id
        , ->
          Meteor.call 'renameRound',
            id: r._id
            name: Random.hexString(16)
            who: who
          , cb
      removeit = (r) ->
        Meteor.call 'deleteRound',
          id: r._id
          who: who
      Meteor.call 'newRound', {name:name,who:who,puzzles:null}, cb
    when 'puzzle'
      followup = (p, cb) ->
        Meteor.call 'addPuzzleToRound',
          puzzle: p._id
          round: data.round._id
        , ->
          Meteor.call 'renamePuzzle',
            id: p._id
            name: Random.hexString(16)
            who: who
          , ->
            Meteor.call 'setAnswer',
              type: "puzzles"
              target: p._id
              answer: Random.choice ['root beer', 'watermelon', 'ice cream']
              who: who
            , cb
      removeit = (p) ->
        Meteor.call 'deletePuzzle',
          id: p._id
          who: who
      Meteor.call 'newPuzzle', {name:name,who:who}, cb

# -- tasks --

addTask "blackboard", ->
  login()
  ensureData (error, data) ->
    addPuzzles(data) unless error?
  { page: 'blackboard' }

addTask "generalChat", ->
  login()
  saySomething 'general/0'
  { page: 'chat', type: 'general', id: '0' }


addTask "puzzleChat", (cb) ->
  # ensure there's a puzzle named "puzzle" in a round named "round" in a
  # roundgroup named "roundgroup"
  ensureData (error, data) ->
    return if error?
    login()
    o = { page: 'chat', type: 'puzzles', id: data.puzzle._id }
    saySomething "#{o.type}/#{o.id}"
    cb o
  undefined

addTask "puzzlePage", (cb) ->
  # ensure there's a puzzle named "puzzle" in a round named "round" in a
  # roundgroup named "roundgroup"
  ensureData (error, data) ->
    return if error?
    login()
    # pick a puzzle
    o = Random.choice [
      #{ type: 'roundgroups', id: data.roundgroup._id }, # no chat for rgs!
      { type: 'rounds', id: data.round._id },
      { type: 'puzzles', id: data.puzzle._id },
    ]
    saySomething "#{o.type}/#{o.id}"
    cb o
  undefined

start = (which, cb) ->
  # select a random task if which is falsy.
  unless tasks[which]
    n = Random.fraction() * totalProb
    which = (name for name of tasks when \
      tasks[name].p.start <= n and n < tasks[name].p.end)[0]
  # ok, execute the task
  console.log 'Starting loadtest:', tasks[which].name
  tasks[which].func(cb)

# exports
share.loadtest =
  start: start

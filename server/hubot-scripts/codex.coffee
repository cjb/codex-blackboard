# Description:
#   Utility commands for Codexbot
#
# Commands:
#   hubot bot: The answer to <puzzle> is <answer>
#   hubot bot: Call in <answer> for <puzzle>
#   hubot bot: Delete the answer to <puzzle>
#   hubot bot: <puzzle> is a new puzzle in round <round>
#   hubot bot: Delete puzzle <puzzle>
#   hubot bot: <round> is a new round in group <group>
#   hubot bot: Delete round <name>
#   hubot bot: <roundgroup> is a new round group
#   hubot bot: Delete round group <roundgroup>

share.hubot.codex = (robot) ->

## ANSWERS

# setAnswer
  robot.commands.push 'bot the answer to <puzzle> is <answer>'
  robot.respond /The answer to (.*?) is (.*)$/i, (msg) ->
    name = msg.match[1]
    answer = msg.match[2]
    who = msg.envelope.user.id
    puzzle = Meteor.call "getByName",
      name: name
      optional_type: "puzzles"
    if not puzzle
      msg.reply "I can't find a puzzle called #{name}."
      return
    res = Meteor.call "setAnswer",
      puzzle: puzzle.object._id
      answer: answer
      who: who
    unless res
      msg.reply msg.random ["I knew that!","Not news to me.","Already known."]
      return
    solution_banter = [
      "Huzzah!"
      "Yay!"
      "Pterrific!"
      "Who'd have thought?"
      "#{answer}?  Really?  Whoa."
      "Rock on!"
      "#{puzzle.object.name} bites the dust!"
      "#{puzzle.object.name}, meet #{answer}.  We rock!"
    ]
    msg.reply msg.random solution_banter
    msg.finish()

  # newCallIn
  robot.commands.push 'bot call in <answer> for <puzzle>'
  robot.respond /Call in (.*?) for (.*)$/i, (msg) ->
    answer = msg.match[1]
    name = msg.match[2]
    who = msg.envelope.user.id
    puzzle = Meteor.call "getByName",
      name: name
      optional_type: "puzzles"
    if not puzzle
      msg.reply "I can't find a puzzle called #{name}."
      return
    Meteor.call "newCallIn",
      puzzle: puzzle.object._id
      answer: answer
      who: who
      name: name + ':' + answer
    msg.reply "Okay, #{answer} for #{puzzle.object.name} added to call-in list!"
    msg.finish()

# deleteAnswer
  robot.commands.push 'bot delete the answer to <puzzle>'
  robot.respond /Delete the answer (?:to|for) (.*)$/i, (msg) ->
    name = msg.match[1]
    who = msg.envelope.user.id
    puzzle = Meteor.call "getByName",
      name: name
      optional_type: "puzzles"
    if not puzzle
      msg.reply "I can't find a puzzle called #{name}."
      return
    Meteor.call "deleteAnswer",
      puzzle: puzzle.object._id
      who: who
    msg.reply "Okay, I deleted the answer to #{puzzle.object.name}."
    msg.finish()

## PUZZLES

# newPuzzle
  robot.commands.push 'bot <puzzle> is a new puzzle in round <round>'
  robot.respond /(.*?) is a new puzzle in round (.*)$/i, (msg) ->
    pname = msg.match[1]
    rname = msg.match[2]
    who = msg.envelope.user.id
    round = Meteor.call "getByName",
      name: rname
      optional_type: "rounds"
    if not round
      msg.reply "I can't find a round called #{rname}."
      return
    puzzle = Meteor.call "newPuzzle",
      name: pname
      who: who
    Meteor.call "addPuzzleToRound",
      round: round.object._id
      puzzle: puzzle._id
      who: who
    msg.reply "Okay, I added #{puzzle.name} to #{round.object.name}."
    msg.finish()

# deletePuzzle
  robot.commands.push 'bot delete puzzle <puzzle>'
  robot.respond /Delete puzzle (.*)$/i, (msg) ->
    name = msg.match[1]
    who = msg.envelope.user.id
    puzzle = Meteor.call "getByName",
      name: name
      optional_type: "puzzles"
    if not puzzle
      msg.reply "I can't find a puzzle called #{name}."
      return
    res = Meteor.call "deletePuzzle",
      id: puzzle.object._id
      who: who
    if res
      msg.reply "Okay, I deleted #{puzzle.object.name}."
    else
      msg.reply "Something went wrong."
    msg.finish()

## ROUNDS

# newRound
  robot.commands.push 'bot <round> is a new round in group <group>'
  robot.respond /(.*?) is a new round in group (.*)$/i, (msg) ->
    rname = msg.match[1]
    gname = msg.match[2]
    who = msg.envelope.user.id
    group = Meteor.call "getByName",
      name: gname
      optional_type: "roundgroups"
    unless group
      msg.reply "I can't find a round ground called #{gname}."
      return
    round = Meteor.call "newRound",
      name: rname
      who: who
    unless round
      msg.reply "Something went wrong (couldn't create new round)."
      return
    res = Meteor.call "addRoundToGroup",
      round: round._id
      group: group.object._id
      who: who
    unless res
      msg.reply "Something went wrong (couldn't add round to group)"
      return
    msg.reply "Okay, I created round #{rname} in #{group.object.name}."
    msg.finish()

# deleteRound
  robot.commands.push 'bot delete round <round>'
  robot.respond /Delete round (.*)$/i, (msg) ->
    rname = msg.match[1]
    who = msg.envelope.user.id
    round = Meteor.call "getByName",
      name: rname
      optional_type: "rounds"
    unless round
      msg.reply "I can't find a round called #{rname}."
      return
    res = Meteor.call "deleteRound",
      id: round.object._id
      who: who
    unless res
      msg.reply "Couldn't delete round. (Are there still puzzles in it?)"
      return
    msg.reply "Okay, I deleted round #{round.object.name}."
    msg.finish()

## ROUND GROUPS

# newRoundGroup
  robot.commands.push 'bot <group> is a new round group'
  robot.respond /(.*?) is a new round group$/i, (msg) ->
    gname = msg.match[1]
    group = Meteor.call "newRoundGroup",
      name: gname
      who: "codexbot"
    msg.reply "Okay, I created round group #{group.name}."
    msg.finish()

# deleteRoundGroup
  robot.commands.push 'bot delete round group <group>'
  robot.respond /Delete round group (.*)$/i, (msg) ->
    gname = msg.match[1]
    who = msg.envelope.user.id
    group = Meteor.call "getByName",
      name: gname
      optional_type: "roundgroups"
    unless group
      msg.reply "I can't find a round group called #{gname}."
      return
    res = Meteor.call "deleteRoundGroup",
      id: group.object._id
      who: who
    unless res
      msg.reply "Somthing went wrong."
      return
    msg.reply "Okay, I deleted round group #{gname}."
    msg.finish()

# Description:
#   Utility commands for Codexbot
#
# Commands:
#   hubot: The answer to <puzzle> is <answer>
#   hubot: Call in <answer> for <puzzle>
#   hubot: Delete the answer to <puzzle>
#   hubot: <puzzle> is a new puzzle in round <round>
#   hubot: Delete puzzle <puzzle>
#   hubot: <round> is a new round in group <group>
#   hubot: Delete round <name>
#   hubot: <roundgroup> is a new round group
#   hubot: Delete round group <roundgroup>

module.exports = (robot) ->

## ANSWERS

# setAnswer
  robot.respond /The answer to (.*?) is (.*)$/i, (msg) ->
    robot.ddpclient.call "getByName", [
      name: msg.match[1]
      optional_type: "puzzles"
    ], (err, puzzle) ->
      if err or not puzzle
        console.log err, puzzle
        return
      else
        robot.ddpclient.call "setAnswer", [
          puzzle: puzzle.object._id
          answer: msg.match[2]
          who: "codexbot"
        ], (err, res) ->
          if err or not res
            console.log err, res

  robot.respond /Call in (.*?) for (.*)$/i, (msg) ->
    answer = msg.match[1]
    name = msg.match[2]
    robot.ddpclient.call "getByName", [
      name: name
      optional_type: "puzzles"
    ], (err, puzzle) ->
      if err or not puzzle
        console.log err, puzzle
        return
      else
        robot.ddpclient.call "newCallIn", [
          puzzle: puzzle.object._id
          answer: answer
          who: "codexbot"
          name: name + answer
        ], (err, res) ->
          if err or not res
            console.log err, res

# deleteAnswer
  robot.respond /Delete the answer to (.*)$/i, (msg) ->
    robot.ddpclient.call "getByName", [
      name: msg.match[1]
      optional_type: "puzzles"
    ], (err, puzzle) ->
      if err or not puzzle
        console.log err, puzzle
        return
      else
        robot.ddpclient.call "deleteAnswer", [
          puzzle: puzzle.object._id
          who: "codexbot"
        ], (err, res) ->
          if err or not res
            console.log err, res

## PUZZLES

# newPuzzle
  robot.respond /(.*?) is a new puzzle in round (.*)$/i, (msg) ->
    robot.ddpclient.call "getByName", [
      name: msg.match[2]
      optional_type: "rounds"
    ], (err, round) ->
      if err or not round
        console.log err, round
        return
      else
        robot.ddpclient.call "newPuzzle", [
          name: msg.match[1]
          who: "codexbot"
        ], (err, puzzle) ->
          if err or not puzzle
            console.log err, puzzle
            return
          else
            robot.ddpclient.call "addPuzzleToRound", [
              round: round.object._id
              puzzle: puzzle._id
              who: "codexbot"
            ], (err, res) ->
              if err or not res
                console.log err, res

# deletePuzzle
  robot.respond /Delete puzzle (.*)$/i, (msg) ->
    robot.ddpclient.call "getByName", [
      name: msg.match[1]
      optional_type: "puzzles"
    ], (err, puzzle) ->
      if err or not puzzle
        console.log err, puzzle
        return
      else
        robot.ddpclient.call "deletePuzzle", [
          id: puzzle.object._id
          who: "codexbot"
        ], (err, res) ->
          if err or not res
            console.log err, res

## ROUNDS

# newRound
  robot.respond /(.*?) is a new round in group (.*)$/i, (msg) ->
    robot.ddpclient.call "getByName", [
      name: msg.match[2]
      optional_type: "roundgroups"
    ], (err, rg) ->
      if err or not rg
        console.log err, rg
        return
      else
        robot.ddpclient.call "newRound", [
          name: msg.match[1]
          who: "codexbot"
        ], (err, round) ->
          if err or not round
            console.log err, round
            return
          else
            robot.ddpclient.call "addRoundToGroup", [
              round: round._id
              group: rg.object._id
              who: "codexbot"
            ], (err, res) ->
              if err or not res
                console.log err, res

# deleteRound
  robot.respond /Delete round (.*)$/i, (msg) ->
    robot.ddpclient.call "getByName", [
      name: msg.match[1]
      optional_type: "rounds"
    ], (err, round) ->
      if err or not round
        console.log err, round
        return
      else
        robot.ddpclient.call "deleteRound", [
          id: round.object._id
          who: "codexbot"
        ], (err, res) ->
          if err or not res
            console.log err, res

## ROUND GROUPS

# newRoundGroup
  robot.respond /(.*?) is a new round group/i, (msg) ->
    robot.ddpclient.call "newRoundGroup", [
      name: msg.match[1]
      who: "codexbot"
    ], (err, rg) ->
      if err or not rg
        console.log err, rg

# deleteRoundGroup
  robot.respond /Delete round group (.*)$/i, (msg) ->
    robot.ddpclient.call "getByName", [
      name: msg.match[1]
      optional_type: "roundgroups"
    ], (err, rg) ->
      if err or not rg
        console.log err, rg
        return
      else
        robot.ddpclient.call "deleteRoundGroup", [
          id: rg.object._id
          who: "codexbot"
        ], (err, res) ->
          if err or not res
            console.log err, res

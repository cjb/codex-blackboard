# if the database is empty on server start, create some sample data.
Meteor.startup ->
  if RoundGroups.find().count() is 0
    # note that Meteor.call is async... this causes some slight issues...
    Meteor.call "newRoundGroup", name: "First Group", (error, rg1) ->
        Meteor.call "newRound", name: "Pluto", (error, r1) ->
          Meteor.call "addRoundToGroup", r1, rg1
          Meteor.call "newPuzzle",
            name: "The Plutonian Transport Agency"
            answer: "SOLUTION"
            tags: [{name: "status", value: "stuck"}]
          , (error, p1) ->
            Meteor.call "addPuzzleToRound", p1, r1

        Meteor.call "newRound", name: "Kronos", (error, r2) ->
          Meteor.call "addRoundToGroup", r2, rg1
          Meteor.call "newPuzzle",
            name: "The Thin Red Line"
            answer: "SOLVENT"
          , (error, p2) ->
            Meteor.call "addPuzzleToRound", p2, r2

    Meteor.call "newRoundGroup", name: "Second Group", (error, rg2) ->
      Meteor.call "newRound", name: "Quartet", (error, r3) ->
        Meteor.call "addRoundToGroup", r3, rg2

    # a new puzzle, not in any round
    Meteor.call "newPuzzle"
      name: "Space Invader"

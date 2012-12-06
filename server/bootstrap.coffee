# if the database is empty on server start, create some sample data.
Meteor.startup ->
  if Rounds.find().count() is 0
    rounds = [ 
      {
        id: "1",
        order: "1",
        name: "Pluto",
      },
      {
        id: "2",
        order: "2",
        name: "Kronos",
      },
    ]

    for round in rounds
      timestamp = (new Date()).getTime()
      round_id = Rounds.insert
        id: round.id, order: round.order, name: round.name, created: timestamp

    puzzles = [
      {
        id: "1",
        order: "1",
        round: "1",
        title: "The Plutonian Transport Agency",
        answer: "SOLUTION",
      },
      {
        id: "2",
        order: "2",
        round: "2",
        title: "The Thin Red Line",
        answer: "SOLVENT",
      },
      {
        id: "3",
        order: "3",
        round: "2",
        title: "Space Invader",
        answer: "",
      },
    ]

    for puzzle in puzzles
      puzzle_id = Puzzles.insert id: puzzle.id, order: puzzle.order, round: puzzle.round, title: puzzle.title, answer: puzzle.answer

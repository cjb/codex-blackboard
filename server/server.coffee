Meteor.publish 'rounds', -> Rounds.find()

Meteor.publish 'puzzles', (round) -> Puzzles.find({round: round})


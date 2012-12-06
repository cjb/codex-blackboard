Meteor.subscribe "rounds"
Meteor.subscribe "puzzles"

Template.rounds.rounds = -> Rounds.find {}
Template.puzzles.puzzles = -> Puzzles.find {}

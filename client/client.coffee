Template.rounds.rounds = -> Rounds.find {}
Template.puzzles.puzzles = -> Puzzles.find {}

# Router
BlackboardRouter = Backbone.Router.extend
  routes:
    "round/:round": "RoundPage"
    "puzzle/:puzzle": "PuzzlePage"

  RoundPage: (round) ->
    console.log("in RoundPage for round " + round)
    Session.set "round", round

  PuzzlePage: (puzzle) ->
    console.log("in PuzzlePage for puzzle " + puzzle)
    Session.set "puzzle", puzzle


# Subscriptions
Meteor.autosubscribe ->
  round = Session.get 'round'
  Meteor.subscribe 'puzzles', round if round
  Meteor.subscribe 'rounds'

Meteor.autosubscribe ->
  Puzzles.find
    round: Session.get "round"
  .observe
    added: (item) ->
      console.log(item)

Router = new BlackboardRouter()
Backbone.history.start {pushState: true}

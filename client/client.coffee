# Three "top level" templates:
#   "blackboard" -- main blackboard page
#   "puzzle"     -- puzzle information page
#   "round"      -- round information (much like the puzzle page)

Template.blackboard.rounds = -> Rounds.find {}
Template.bb_rounds.rounds  = -> Rounds.find {}
Template.bb_puzzles.puzzles = -> Puzzles.find {}
Template.page.currentPage = -> (Session.get "currentPage") or "blackboard"

Handlebars.registerHelper "equal", (a, b) -> a is b

# Router
BlackboardRouter = Backbone.Router.extend
  routes:
    "/": "BlackboardPage"
    "round/:round": "RoundPage"
    "puzzle/:puzzle": "PuzzlePage"

  Blackboard: ->
    Session.set "currentPage", "blackboard"

  RoundPage: (round) ->
    Session.set "currentPage", "round"
    Session.set "round", round

  PuzzlePage: (puzzle) ->
    Session.set "currentPage", "puzzle"
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

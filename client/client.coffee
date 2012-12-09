# Three "top level" templates:
#   "blackboard" -- main blackboard page
#   "puzzle"     -- puzzle information page
#   "round"      -- round information (much like the puzzle page)

Template.page.currentPage = -> (Session.get "currentPage") or "blackboard"

Template.blackboard.roundgroups = -> RoundGroups.find {}
Template.blackboard.rounds = -> Rounds.find _id: $in: this.rounds
Template.blackboard_round.puzzles = -> Puzzles.find _id: $in: this.puzzles
Template.blackboard_round.events
  "click .round-link": (event, template) ->
    event.preventDefault()
    round = template.data
    Router.goToRound round
Template.blackboard_puzzle.events
  "click .puzzle-link": (event, template) ->
    event.preventDefault()
    puzzle = template.data
    Router.goToPuzzle puzzle

Template.puzzle.puzzle = -> Puzzles.findOne(Session.get "id")
Template.round.round = -> Rounds.findOne(Session.get "id")

Handlebars.registerHelper "equal", (a, b) -> a is b

# Router
BlackboardRouter = Backbone.Router.extend
  routes:
    "": "BlackboardPage"
    "round/:round": "RoundPage"
    "puzzle/:puzzle": "PuzzlePage"

  BlackboardPage: ->
    Session.set "currentPage", "blackboard"
    $("title").text("Blackboard")

  RoundPage: (round) ->
    Session.set "currentPage", "round"
    Session.set "id", round
    $("title").text("Round: "+Rounds.findOne(round).name)

  PuzzlePage: (puzzle) ->
    Session.set "currentPage", "puzzle"
    Session.set "id", puzzle
    $("title").text("Puzzle: "+Puzzles.findOne(puzzle).name)

  goToRound: (round) ->
    this.navigate("/round/"+round._id, {trigger:true})

  goToPuzzle: (puzzle) ->
    this.navigate("/puzzle/"+puzzle._id, {trigger:true})

# Subscriptions
#Meteor.subscribe "roundgroups"
#Meteor.subscribe "rounds"
#Meteor.subscribe "puzzles"

#Meteor.autosubscribe ->
#  round = Session.get 'round'
#  Meteor.subscribe 'puzzles', round if round
#  Meteor.subscribe 'rounds'
#
#Meteor.autosubscribe ->
#  Puzzles.find
#    round: Session.get "round"
#  .observe
#    added: (item) ->
#      console.log(item)

Router = new BlackboardRouter()
Backbone.history.start {pushState: true}

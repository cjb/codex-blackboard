# Three "top level" templates:
#   "blackboard" -- main blackboard page
#   "puzzle"     -- puzzle information page
#   "round"      -- round information (much like the puzzle page)

Template.page.currentPage = -> (Session.get "currentPage") or "blackboard"

Handlebars.registerHelper "equal", (a, b) -> a is b

# Router
BlackboardRouter = Backbone.Router.extend
  routes:
    "": "BlackboardPage"
    "r/:round": "RoundPage"
    "p/:puzzle": "PuzzlePage"
    "c/:type/:id": "ChatPage"

  BlackboardPage: ->
    Session.set "currentPage", "blackboard"
    $("title").text("Blackboard")

  RoundPage: (round) ->
    Session.set "currentPage", "round"
    Session.set "type", "round"
    Session.set "id", round
    $("title").text("Round: "+Rounds.findOne(round).name)

  PuzzlePage: (puzzle) ->
    Session.set "currentPage", "puzzle"
    Session.set "type", "puzzle"
    Session.set "id", puzzle
    $("title").text("Puzzle: "+Puzzles.findOne(puzzle).name)

  ChatPage: (type,id) ->
    Session.set "currentPage", "chat"
    Session.set "type", type
    Session.set "id", id
    name = if type is "general" then "General" else \
      collection(type).findOne(id).name
    $("title").text("Chat: "+name)


  goToRound: (round) ->
    this.navigate("/r/"+round._id, {trigger:true})

  goToPuzzle: (puzzle) ->
    this.navigate("/p/"+puzzle._id, {trigger:true})

  goToChat: (type, id) ->
    this.navigate("/c/"+type+"/"+id, {trigger:true})
    $.cookie "room_name", type+"/"+id, {expires: 365}

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

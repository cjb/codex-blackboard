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
    Session.set "type", "general"
    Session.set "id", "0"

  RoundPage: (round) ->
    Session.set "currentPage", "round"
    Session.set "type", "round"
    Session.set "id", round

  PuzzlePage: (puzzle) ->
    Session.set "currentPage", "puzzle"
    Session.set "type", "puzzle"
    Session.set "id", puzzle

  ChatPage: (type,id) ->
    type = "puzzle" if type is "p"
    type = "round" if type is "r"
    id = "0" if type is "general"
    Session.set "currentPage", "chat"
    Session.set "type", type
    Session.set "id", id
    Session.set "room_name", (type+'/'+id)

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

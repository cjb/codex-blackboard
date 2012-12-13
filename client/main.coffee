# "Top level" templates:
#   "blackboard" -- main blackboard page
#   "puzzle"     -- puzzle information page
#   "round"      -- round information (much like the puzzle page)
#   "chat"       -- chat room

Template.page.currentPage = -> (Session.get "currentPage") or "blackboard"

Handlebars.registerHelper "equal", (a, b) -> a is b

CLIENT_UUID = Meteor.uuid() # this identifies this particular client instance

# subscribe to the all-names feed all the time
Meteor.subscribe 'all-names'

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
    Session.set "type", "rounds"
    Session.set "id", round

  PuzzlePage: (puzzle) ->
    Session.set "currentPage", "puzzle"
    Session.set "type", "puzzles"
    Session.set "id", puzzle

  ChatPage: (type,id) ->
    type = "puzzles" if type is "p"
    type = "rounds" if type is "r"
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

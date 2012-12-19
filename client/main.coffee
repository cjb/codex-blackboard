# "Top level" templates:
#   "blackboard" -- main blackboard page
#   "puzzle"     -- puzzle information page
#   "round"      -- round information (much like the puzzle page)
#   "chat"       -- chat room

Handlebars.registerHelper "equal", (a, b) -> a is b

# session variables we want to make available from all templates
do -> for v in ['currentPage']
  Handlebars.registerHelper v, () -> Session.get(v)
Handlebars.registerHelper 'currentPageEquals', (arg) ->
  # register a more precise dependency on the value of currentPage
  Session.equals 'currentPage', arg
Handlebars.registerHelper 'canEdit', () ->
  (Session.get 'nick') and (Session.get 'canEdit')
Handlebars.registerHelper 'editing', (args..., options) ->
  return false unless (Session.get 'nick') and (Session.get 'canEdit')
  return Session.equals 'editing', args.join('/')

CLIENT_UUID = Meteor.uuid() # this identifies this particular client instance
DEFAULT_HOST = 'ihtfp.us' # this is used to create gravatars from nicks

# subscribe to the all-names feed all the time
Meteor.subscribe 'all-names'
# always subscribe to your own nick
Meteor.autosubscribe ->
  return unless Session.get('nick')
  Meteor.subscribe 'my-nick', Session.get('nick')

# Router
BlackboardRouter = Backbone.Router.extend
  routes:
    "": "BlackboardPage"
    "rounds/:round": "RoundPage"
    "puzzles/:puzzle": "PuzzlePage"
    "chat/:type/:id": "ChatPage"

  BlackboardPage: ->
    this.Page("blackboard", "general", "0")

  RoundPage: (id) ->
    this.Page("round", "rounds", id)

  PuzzlePage: (id) ->
    this.Page("puzzle", "puzzles", id)

  ChatPage: (type,id) ->
    id = "0" if type is "general"
    this.Page("chat", type, id)
    Session.set "room_name", (type+'/'+id)

  Page: (page, type, id) ->
    Session.set "currentPage", page
    Session.set "type", type
    Session.set "id", id
    # cancel modal if it was active
    $('#nickPickModal').modal 'hide'

  urlFor: (type,id) ->
    "/#{type}/#{id}"
  chatUrlFor: (type, id) ->
    "/chat" + this.urlFor(type,id)

  goToRound: (round) ->
    this.navigate(this.urlFor("rounds",round._id), {trigger:true})

  goToPuzzle: (puzzle) ->
    this.navigate(this.urlFor("puzzles",puzzle._id), {trigger:true})

  goToChat: (type, id) ->
    this.navigate(this.chatUrlFor(type, id), {trigger:true})

Router = new BlackboardRouter()
Backbone.history.start {pushState: true}

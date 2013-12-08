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
Handlebars.registerHelper 'typeEquals', (arg) ->
  # register a more precise dependency on the value of type
  Session.equals 'type', arg
Handlebars.registerHelper 'canEdit', () ->
  (Session.get 'nick') and (Session.get 'canEdit')
Handlebars.registerHelper 'editing', (args..., options) ->
  return false unless (Session.get 'nick') and (Session.get 'canEdit')
  return Session.equals 'editing', args.join('/')

WIKI_HOST = 'http://wiki.codexian.us'
Handlebars.registerHelper 'wiki', (options) ->
  contents = options.fn(this)
  return WIKI_HOST unless contents
  "#{WIKI_HOST}/index.php?title=#{contents}"

Handlebars.registerHelper 'linkify', (options) ->
  contents = options.fn(this)
  contents = convertURLsToLinksAndImages(Handlebars._escape(contents))
  return new Handlebars.SafeString(contents)

CLIENT_UUID = Random.id() # this identifies this particular client instance
DEFAULT_HOST = 'codexian.us' # this is used to create gravatars from nicks

# subscribe to the all-names feed all the time
Meteor.subscribe 'all-names'
# subscribe to all nicks all the time
Meteor.subscribe 'all-nicks'
# we might subscribe to all-puzzles, all-rounds, all-roundgroups, too.
if BB_SUB_ALL
  Meteor.subscribe 'all-roundgroups'
  Meteor.subscribe 'all-rounds'
  Meteor.subscribe 'all-puzzles'

# Router
BlackboardRouter = Backbone.Router.extend
  routes:
    "": "BlackboardPage"
    "rounds/:round": "RoundPage"
    "puzzles/:puzzle": "PuzzlePage"
    "chat/:type/:id": "ChatPage"
    "chat/:type/:id/:timestamp": "ChatPage"
    "oplogs/:timestamp": "OpLogPage"

  BlackboardPage: ->
    this.Page("blackboard", "general", "0")

  RoundPage: (id) ->
    this.Page("round", "rounds", id)
    Session.set "timestamp", 0

  PuzzlePage: (id) ->
    this.Page("puzzle", "puzzles", id)
    Session.set "timestamp", 0

  ChatPage: (type,id,timestamp=0) ->
    id = "0" if type is "general"
    this.Page("chat", type, id)
    Session.set "timestamp", +timestamp

  OpLogPage: (timestamp) ->
    this.Page("oplog", "general", "0")
    Session.set "timestamp", timestamp

  Page: (page, type, id) ->
    Session.set "currentPage", page
    Session.set "type", type
    Session.set "id", id
    Session.set "room_name", (type+'/'+id)
    # cancel modals if they were active
    $('#nickPickModal').modal 'hide'
    $('#confirmModal').modal 'hide'

  urlFor: (type,id) ->
    "/#{type}/#{id}"
  chatUrlFor: (type, id, timestamp) ->
    "/chat" + this.urlFor(type,id) + (if (+timestamp) then "/#{+timestamp}" else "")

  goToRound: (round) ->
    this.navigate(this.urlFor("rounds",round._id), {trigger:true})

  goToPuzzle: (puzzle) ->
    this.navigate(this.urlFor("puzzles",puzzle._id), {trigger:true})

  goToChat: (type, id, timestamp) ->
    this.navigate(this.chatUrlFor(type, id, timestamp), {trigger:true})

Router = new BlackboardRouter()
Backbone.history.start {pushState: true}

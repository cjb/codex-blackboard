'use strict'
settings = share.settings # import
chat = share.chat # import

# "Top level" templates:
#   "blackboard" -- main blackboard page
#   "puzzle"     -- puzzle information page
#   "round"      -- round information (much like the puzzle page)
#   "chat"       -- chat room
#   "oplogs"     -- operation logs
#   "callins"    -- answer queue
#   "quips"      -- view/edit phone-answering quips
#   "facts"      -- server performance information
Template.registerHelper "equal", (a, b) -> a is b

# session variables we want to make available from all templates
do -> for v in ['currentPage']
  Template.registerHelper v, () -> Session.get(v)
Template.registerHelper 'currentPageEquals', (arg) ->
  # register a more precise dependency on the value of currentPage
  Session.equals 'currentPage', arg
Template.registerHelper 'typeEquals', (arg) ->
  # register a more precise dependency on the value of type
  Session.equals 'type', arg
Template.registerHelper 'canEdit', () ->
  (Session.get 'nick') and (Session.get 'canEdit') and \
  (Session.equals 'currentPage', 'blackboard')
Template.registerHelper 'editing', (args..., options) ->
  canEdit = options?.hash?.canEdit or (Session.get 'canEdit')
  return false unless (Session.get 'nick') and canEdit
  return Session.equals 'editing', args.join('/')

Template.registerHelper 'wikiRP', (options) ->
  [r,p] = [options.hash?.r, options.hash?.p]
  "#{settings.WIKI_HOST}/wiki/#{settings.HUNT_YEAR}_R#{r}P#{p}"
Template.registerHelper 'wiki', (options) ->
  title = options.hash?.title
  return settings.WIKI_HOST unless title
  "#{settings.WIKI_HOST}/wiki/#{title}"

Template.registerHelper 'linkify', (contents) ->
  contents = chat.convertURLsToLinksAndImages(UI._escape(contents))
  return new Spacebars.SafeString(contents)

Template.registerHelper 'compactHeader', () ->
  (Session.equals 'currentPage', 'chat')

# subscribe to the all-names feed all the time
Meteor.subscribe 'all-names'
# subscribe to all nicks all the time
Meteor.subscribe 'all-nicks'
# we might subscribe to all-roundsandpuzzles, too.
if settings.BB_SUB_ALL
  Meteor.subscribe 'all-roundsandpuzzles'
# we also always subscribe to the last-pages feed; see chat.coffee

# Router
BlackboardRouter = Backbone.Router.extend
  routes:
    "": "BlackboardPage"
    "rounds/:round": "RoundPage"
    "puzzles/:puzzle": "PuzzlePage"
    "roundgroups/:roundgroup": "RoundGroupPage"
    "chat/:type/:id": "ChatPage"
    "chat/:type/:id/:timestamp": "ChatPage"
    "oplogs/:timestamp": "OpLogPage"
    "callins": "CallInPage"
    "quips/:id": "QuipPage"
    "facts": "FactsPage"
    "loadtest/:which": "LoadTestPage"

  BlackboardPage: ->
    this.Page("blackboard", "general", "0")

  RoundPage: (id) ->
    this.Page("round", "rounds", id)
    Session.set "timestamp", 0

  PuzzlePage: (id) ->
    this.Page("puzzle", "puzzles", id)
    Session.set "timestamp", 0

  RoundGroupPage: (id) ->
    this.goToChat "roundgroups", id, 0

  ChatPage: (type,id,timestamp=0) ->
    id = "0" if type is "general"
    this.Page("chat", type, id)
    Session.set "timestamp", +timestamp

  OpLogPage: (timestamp) ->
    this.Page("oplog", "general", "0")
    Session.set "timestamp", timestamp

  CallInPage: ->
    this.Page("callins", "general", "0")

  QuipPage: (id) ->
    this.Page("quip", "quips", id)

  FactsPage: ->
    this.Page("facts", "general", "0")

  LoadTestPage: (which) ->
    # redirect to one of the 'real' pages, so that client has the
    # proper subscriptions, etc; plus launch a background process
    # to perform database mutations
    cb = (args) =>
      {page,type,id,timestamp} = args
      url = switch page
        when 'chat' then this.chatUrlFor type, id, timestamp
        when 'oplogs' then this.urlFor 'oplogs', timestamp # bit of a hack
        when 'blackboard' then Meteor._relativeToSiteRootUrl "/"
        when 'facts' then this.urlFor 'facts', '' # bit of a hack
        else this.urlFor type, id
      this.navigate(url, {trigger:true})
    r = share.loadtest.start which, cb
    cb(r) if r? # immediately navigate if method is synchronous

  Page: (page, type, id) ->
    Session.set
      currentPage: page
      type: type
      id: id
      room_name: (type+'/'+id)
    # cancel modals if they were active
    $('#nickPickModal').modal 'hide'
    $('#confirmModal').modal 'hide'

  urlFor: (type,id) ->
    Meteor._relativeToSiteRootUrl "/#{type}/#{id}"
  chatUrlFor: (type, id, timestamp) ->
    (Meteor._relativeToSiteRootUrl "/chat#{this.urlFor(type,id)}") + \
    (if (+timestamp) then "/#{+timestamp}" else "")

  goTo: (type,id) ->
    this.navigate(this.urlFor(type,id), {trigger:true})

  goToRound: (round) -> this.goTo("rounds", round._id)

  goToPuzzle: (puzzle) ->  this.goTo("puzzles", puzzle._id)

  goToChat: (type, id, timestamp) ->
    this.navigate(this.chatUrlFor(type, id, timestamp), {trigger:true})

share.Router = new BlackboardRouter()
Backbone.history.start {pushState: true}

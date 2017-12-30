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

notificationDeps = {}

keystring = (k) -> "notification_#{k}"

# Chrome for Android only lets you use Notifications via
# ServiceWorkerRegistration, not directly with the Notification class.
# It appears no other browser (that isn't derived from Chrome) is like that.
# Since there's no capability to detect, we have to use user agent.
isAndroidChrome = -> /Android.*Chrome\/[.0-9]*/.test(navigator.userAgent)

notificationDefaults =
  callins: false
  answers: true
  announcements: true
  'new-puzzles': true
  stuck: false

share.notification =
  count: () ->
    notificationDeps['@count'] ?= new Tracker.Dependency
    notificationDeps['@count'].depend()
    i = 0
    for stream, def of notificationDefaults
      if localStorage.getItem(keystring stream) is "true"
        i += 1
    return i
  set: (k, v) ->
    ks = keystring k
    v = notificationDefaults[k] if v is undefined
    was = localStorage.getItem(ks)
    localStorage.setItem(ks, v)
    notificationDeps[ks] ?= new Tracker.Dependency
    notificationDeps[ks].changed()
    if was isnt v
      notificationDeps['@count'] ?= new Tracker.Dependency
      notificationDeps['@count'].changed()
  get: (k) ->
    ks = keystring k
    notificationDeps[ks] ?= new Tracker.Dependency
    notificationDeps[ks].depend()
    v = localStorage.getItem(ks)
    return unless v?
    v is "true"
  # On android chrome, we clobber this with a version that uses the
  # ServiceWorkerRegistration.
  notify: (title, settings) ->
    new Notification title, settings
  ask: ->
    Notification.requestPermission (ok) ->
      Session.set 'notifications', ok
      setupNotifications() if ok is 'granted'

setupNotifications = ->
  if isAndroidChrome()
    navigator.serviceWorker.register(Meteor._relativeToSiteRootUrl 'empty.js').then((reg) ->
      share.notification.notify = (title, settings) ->
        reg.showNotification title, settings
      finishSetupNotifications()
    ).catch (error) -> Session.set 'notifications', 'default'
    return
  finishSetupNotifications()

finishSetupNotifications = ->
  for stream, def of notificationDefaults
    share.notification.set(stream, def) unless share.notification.get(stream)?

Meteor.startup ->
  now = share.model.UTCNow() + 3
  Tracker.autorun ->
    return if share.notification.count() is 0 # unsubscribes
    p = share.chat.pageForTimestamp 'oplog/0', 0, {subscribe:true}
    return unless p? # wait until page info is loaded
    messages = if p.archived then "oldmessages" else "messages"
    Meteor.subscribe "#{messages}-in-range", p.room_name, p.from, p.to
  share.model.Messages.find({room_name: 'oplog/0', timestamp: $gte: now}).observeChanges
    added: (id, msg) ->
      return unless Notification.permission is 'granted'
      return unless share.notification.get(msg.stream)
      gravatar = $.gravatar chat.nickEmail(msg.nick),
        image: 'wavatar'
        size: 192
        secure: true
      body = msg.body
      if msg.type and msg.id
        body = "#{body} #{share.model.pretty_collection(msg.type)}
                #{share.model.collection(msg.type).findOne(msg.id)?.name}"
      share.notification.notify msg.nick,
        body: body
        tag: id
        icon: gravatar[0].src
  if not Notification
    Session.set 'notifications', 'denied'
    return
  Session.set 'notifications', Notification.permission
  setupNotifications() if Notification.permission is 'granted'

addEventListener 'storage', (event) ->
  return unless event.storageArea is localStorage
  notificationDeps[event.key]?.changed()

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

'use strict'
model = share.model # import
settings = share.settings # import

GENERAL_ROOM = 'Ringhunters'

Session.setDefault
  room_name: 'general/0'
  nick:      ($.cookie("nick") || "")
  mute:      !!$.cookie("mute")
  nobot:     !!$.cookie("nobot")
  type:      'general'
  id:        '0'
  timestamp: 0
  chatReady: false

# Chat/pagination helpers!

# subscribe to last-page feed all the time
lastPageSub = Meteor.subscribe 'last-pages'

# helper method, using the `ready` signal from lastPageSub
# returns `null` iff subscriptions are not ready.
pageForTimestamp = (room_name, timestamp=0, subscribe=false) ->
  timestamp = +timestamp
  if timestamp is 0
    return null unless lastPageSub.ready()
    p = model.Pages.findOne(room_name:room_name, next:null)
    return {
      _id: p?._id
      room_name: room_name
      from: p?.from or 0
      to: 0 # means "and everything else" for message-in-range subscription
    }
  else
    if subscribe and Tracker.active # make sure we unsubscribe if necessary!
      ctx = subscribe?.subscribe or Meteor
      ctx.subscribe 'page-by-timestamp', room_name, timestamp
    model.Pages.findOne(room_name:room_name, to:timestamp)

# helper method to filter messages to match a given page object
messagesForPage = (p, opts={}) ->
  unless p? # return empty cursor unless p is non-null
    return model.Messages.find(timestamp:model.NOT_A_TIMESTAMP)
  messages = if p.archived then "oldmessages" else "messages"
  cond = $gte: +p.from, $lt: +p.to
  delete cond.$lt if cond.$lt is 0
  model.collection(messages).find
    room_name: p.room_name
    timestamp: cond
  , opts

# Globals
instachat = {}
instachat["UTCOffset"] = new Date().getTimezoneOffset() * 60000
instachat["alertWhenUnreadMessages"] = false
instachat["scrolledToBottom"]        = true

# Favicon instance, used for notifications
# (first add host to path)
favicon = badge: (-> false), reset: (-> false)
Meteor.startup ->
  favicon = share.chat.favicon = new Favico
    animation: 'slide'
    fontFamily: 'Droid Sans'
    fontStyle: '700'

Template.chat.helpers
  ready: ->
    type = Session.get 'type'
    type is 'general' or \
      (model.collection(type)?.findOne Session.get("id"))?
  object: ->
    type = Session.get 'type'
    type isnt 'general' and \
      (model.collection(type)?.findOne Session.get("id"))
  solved: ->
    type = Session.get 'type'
    type isnt 'general' and \
      (model.collection(type)?.findOne Session.get("id"))?.solved

# Template Binding
Template.messages.helpers
  room_name: -> Session.get('room_name')
  timestamp: -> +Session.get('timestamp')
  ready: -> Session.equals('chatReady', true) and \
            Template.instance().subscriptionsReady()
  isLastRead: (ts) -> Session.equals('lastread', +ts)
  prevTimestamp: ->
    p = pageForTimestamp Session.get('room_name'), +Session.get('timestamp')
    return unless p?.from
    "/chat/#{p.room_name}/#{p.from}"
  nextTimestamp: ->
    p = pageForTimestamp Session.get('room_name'), +Session.get('timestamp')
    return unless p?.next?
    p = model.Pages.findOne(p.next)
    return unless p?
    "/chat/#{p.room_name}/#{p.to}"
  messages: ->
    room_name = Session.get 'room_name'
    nick = model.canonical(Session.get('nick') or '')
    p = pageForTimestamp room_name, +Session.get('timestamp')
    unless settings.SLOW_CHAT_FOLLOWUPS
      # no follow up formatting, but blazing fast client rendering!
      return messagesForPage p,
        sort: [['timestamp','asc']]
        transform: (m) ->
          _id: m._id
          followup: m.followup or false
          message: m
          isBot: m.nick is 'codexbot' and m.to is null
    messages = messagesForPage p,
      sort: [['timestamp','asc']]
    sameNick = do ->
      prevContext = null
      (m) ->
        thisContext = m.nick + (if m.to then "/#{m.to}" else "")
        thisContext = null if m.system or m.action
        result = thisContext? and (thisContext == prevContext)
        prevContext = thisContext
        return result
    for m, i in messages.fetch()
      followup: sameNick(m)
      message: m
      isBot: m.nick is 'codexbot' and m.to is null
  email: ->
    cn = model.canonical(this.message.nick)
    n = model.Nicks.findOne canon: cn
    return model.getTag(n, 'Gravatar') or "#{cn}@#{settings.DEFAULT_HOST}"
  body: ->
    body = this.message.body or ''
    unless this.message.bodyIsHtml
      body = UI._escape(body)
      body = body.replace(/\n|\r\n?/g, '<br/>')
      body = convertURLsToLinksAndImages(body, this.message._id)
    if doesMentionNick(this.message)
      body = highlightNick(body, this.message.bodyIsHtml)
    new Spacebars.SafeString(body)

selfScroll = null

touchSelfScroll = ->
  Meteor.clearTimeout selfScroll if selfScroll?
  selfScroll = Meteor.setTimeout ->
    selfScroll = null
  , 1000 # ignore browser-generated scroll events for 1 (more) second

Template.messages.helpers
  scrollHack: (m) ->
    touchSelfScroll() # ignore scroll events caused by DOM update
    maybeScrollMessagesView()

Template.messages.onCreated ->
  instachat.scrolledToBottom = true
  this.autorun =>
    invalidator = =>
      instachat.ready = false
      Session.set 'chatReady', false
      hideMessageAlert()
    invalidator()
    room_name = Session.get 'room_name'
    return unless room_name
    this.subscribe 'presence-for-room', room_name
    nick = (if settings.BB_DISABLE_PM then null else Session.get 'nick') or null
    # re-enable private messages, but just in ringhunters (for codexbot)
    if settings.BB_DISABLE_PM and room_name is "general/0"
      nick = (Session.get 'nick') or null
    timestamp = (+Session.get('timestamp'))
    p = pageForTimestamp room_name, timestamp, {subscribe: this}
    return unless p? # wait until page information is loaded
    messages = if p.archived then "oldmessages" else "messages"
    if p.next? # subscribe to the 'next' page
      this.subscribe 'page-by-id', p.next
    # load messages for this page
    ready = 0
    onReady = ->
      if (++ready) is 2
        instachat.ready = true
        Session.set 'chatReady', true
    if nick?
      this.subscribe "#{messages}-in-range-nick", nick, p.room_name, p.from, p.to,
        onReady: onReady
    else
      onReady()
    this.subscribe "#{messages}-in-range", p.room_name, p.from, p.to,
      onReady: onReady
    Tracker.onInvalidate invalidator

whos_here_helper = ->
  roomName = Session.get('type') + '/' + Session.get('id')
  return model.Presence.find {room_name: roomName}, {sort:["nick"]}

Template.chat_header.helpers
  room_name: -> prettyRoomName()
  whos_here: whos_here_helper

# Utility functions

regex_escape = (s) -> s.replace /[$-\/?[-^{|}]/g, '\\$&'

doesMentionNick = (doc, raw_nick=(Session.get 'nick')) ->
  return false unless raw_nick
  return false unless doc.body?
  return false if doc.system # system messages don't count as mentions
  return true if doc.nick is 'thehunt' # special alert for team email!
  nick = model.canonical raw_nick
  return false if nick is doc.nick # messages from yourself don't count
  return true if doc.to is nick # PMs to you count
  n = model.Nicks.findOne(canon: nick)
  realname = if n then model.getTag(n, 'Real Name')
  return false if doc.bodyIsHtml # XXX we could fix this
  # case-insensitive match of canonical nick
  (new RegExp (regex_escape model.canonical nick), "i").test(doc.body) or \
    # case-sensitive match of non-canonicalized nick
    doc.body.indexOf(raw_nick) >= 0 or \
    # match against full name
    (realname and (new RegExp (regex_escape realname), "i").test(doc.body))

highlightNick = (html, isHtml=false) ->
  if isHtml
    "<div class=\"highlight-nick\">" + html + "</div>"
  else
    "<span class=\"highlight-nick\">" + html + "</span>"

# Gruber's "Liberal, Accurate Regex Pattern",
# as amended by @cscott in https://gist.github.com/gruber/249502
urlRE = /\b(?:[a-z][\w\-]+:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]|\((?:[^\s()<>]|(?:\([^\s()<>]+\)))*\))+(?:\((?:[^\s()<>]|(?:\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:\'\".,<>?«»“”‘’])/ig

convertURLsToLinksAndImages = (html, id) ->
  linkOrLinkedImage = (url, id) ->
    inner = url
    url = "http://#{url}" unless /^[a-z][\w\-]+:/.test(url)
    if url.match(/(\.|format=)(png|jpg|jpeg|gif)$/i) and id?
      scrollHacks = [ '', 'end', 'start' ].map (suf) ->
        "onload#{suf}='window.imageScrollHack(this)' "
      inner = "<img src='#{url}' class='inline-image' id='#{id}' #{scrollHacks.join('')}/>"
    "<a href='#{url}' target='_blank'>#{inner}</a>"
  count = 0
  html.replace urlRE, (url) ->
    linkOrLinkedImage url, "#{id}-#{count++}"

isVisible = share.isVisible = do ->
  hidden = "hidden"
  visibilityChange = "visibilitychange"
  if typeof document.hidden isnt "undefined"
    hidden = "hidden"
    visibilityChange = "visibilitychange"
  else if typeof document.mozHidden isnt "undefined"
    hidden = "mozHidden"
    visibilityChange = "mozvisibilitychange"
  else if typeof document.msHidden isnt "undefined"
    hidden = "msHidden"
    visibilityChange = "msvisibilitychange"
  else if typeof document.webkitHidden isnt "undefined"
    hidden = "webkitHidden"
    visibilityChange = "webkitvisibilitychange"

  _visible = new ReactiveVar()
  onVisibilityChange = -> _visible.set !(document[hidden] or false)
  document.addEventListener visibilityChange, onVisibilityChange, false
  onVisibilityChange()
  -> _visible.get()

prettyRoomName = ->
  type = Session.get('type')
  id = Session.get('id')
  name = if type is "general" then GENERAL_ROOM else \
    model.Names.findOne(id)?.name
  return (name or "unknown")

joinRoom = (type, id, timestamp) ->
  roomName = type + '/' + id
  # xxx: could record the room name in a set here.
  Session.set "room_name", roomName
  share.Router.goToChat(type, id, timestamp ? Session.get('timestamp'))
  Tracker.afterFlush -> scrollMessagesView()
  $("#messageInput").select()
  startupChat()

maybeScrollMessagesView = do ->
  pending = false
  return ->
    return unless instachat.scrolledToBottom and not pending
    pending = true
    Tracker.afterFlush ->
      pending = false
      scrollMessagesView()

scrollMessagesView = ->
  touchSelfScroll()
  instachat.scrolledToBottom = true
  # first try using html5, then fallback to jquery
  last = document?.querySelector?('.bb-chat-messages > *:last-child')
  if last?.scrollIntoView?
    last.scrollIntoView()
  else
    $("body").scrollTo 'max'
  # the scroll handler below will reset scrolledToBottom to be false
  instachat.scrolledToBottom = true

# Event Handlers
['mute','nobot'].forEach (btn) ->
  $(document).on 'click', "button.#{btn}", ->
    if Session.get btn
      $.removeCookie btn, {path:'/'}
    else
      $.cookie btn, true, {expires: 365, path: '/'}

    Session.set btn, !!$.cookie btn
Tracker.autorun ->
  if Session.equals('nobot', true)
    document.documentElement.classList.add('bb-nobot')
  else
    document.documentElement.classList.remove('bb-nobot')
  touchSelfScroll() # ignore scroll event generated by CSS relayout
  maybeScrollMessagesView()

# ensure that we stay stuck to bottom even after images load
imageScrollHack = window.imageScrollHack = ->
  console.log "#{event.type} event, suppressing scroll (at bottom=#{instachat.scrolledToBottom})"
  touchSelfScroll() # ignore scroll event generated by image resize
  maybeScrollMessagesView()
# note that image load does not delegate, so we can't use it here in
# a document-wide "live" event handler
$(document).on 'mouseenter', '.bb-message-body .inline-image', imageScrollHack

# unstick from bottom if the user manually scrolls
$(window).scroll (event) ->
  return unless Session.equals('currentPage', 'chat')
  #console.log if selfScroll? then 'Self scroll' else 'External scroll'
  return maybeScrollMessagesView() if selfScroll?
  # set to false, just in case older browser doesn't have scroll properties
  instachat.scrolledToBottom = false
  [body, html] = [document.body, document.documentElement]
  return unless html?.scrollTop? and html?.scrollHeight?
  return unless html?.clientHeight?
  SLOP=20
  [scrollPos, scrollMax] = [body.scrollTop+html.clientHeight, body.scrollHeight]
  atBottom = (scrollPos+SLOP >= scrollMax)
  # firefox says that the HTML element is scrolling, not the body element...
  if html.scrollTopMax?
    atBottom = (html.scrollTop+SLOP >= (html.scrollTopMax-1)) or atBottom
  console.log 'Scroll debug:', 'atBottom', atBottom, 'scrollPos', scrollPos, 'scrollMax', scrollMax
  console.log ' body scrollTop', body.scrollTop, 'scrollTopMax', body.scrollTopMax, 'scrollHeight', body.scrollHeight, 'clientHeight', body.clientHeight
  console.log ' html scrollTop', html.scrollTop, 'scrollTopMax', html.scrollTopMax, 'scrollHeight', html.scrollHeight, 'clientHeight', html.clientHeight
  instachat.scrolledToBottom = atBottom

# Form Interceptors
$(document).on 'submit', '#joinRoom', ->
  roomName = $("#roomName").val()
  if not roomName
    # reset to old room name
    $("#roomName").val prettyRoomName()
  # is this the general room?
  else if model.canonical(roomName) is model.canonical(GENERAL_ROOM)
    joinRoom "general", "0", 0
  else
    # try to find room as a group, round, or puzzle name
    n = model.Names.findOne canon: model.canonical(roomName)
    if n
      joinRoom n.type, n._id, 0
    else
      # reset to old room name
      $("#roomName").val prettyRoomName()
  return false

Template.messages_input.helpers
  hasNick: -> Session.get('nick') or false

Template.messages_input.submit = (message) ->
  return unless message
  args =
    nick: Session.get 'nick'
    room_name: Session.get 'room_name'
    body: message
  [word1, rest] = message.split(/\s+([^]*)/, 2)
  switch word1
    when "/me"
      args.body = rest
      args.action = true
    when "/help"
      args.to = args.nick
      args.body = "should read <a href='#{settings.WIKI_HOST}/wiki/Chat_System' target='_blank'>Chat System</a> on the wiki"
      args.bodyIsHtml = true
      args.action = true
    when "/users", "/show", "/list"
      args.to = args.nick
      args.action = true
      whos_here = \
        model.Presence.find({room_name: args.room_name}, {sort:["nick"]}) \
        .fetch().map (obj) ->
          if obj.foreground then obj.nick else "(#{obj.nick})"
      if whos_here.length == 0
        whos_here = "nobody"
      else if whos_here.length == 1
        whos_here = whos_here[0]
      else if whos_here.length == 2
        whos_here = whos_here.join(' and ')
      else
        whos_here[whos_here.length-1] = 'and ' + whos_here[whos_here.length-1]
        whos_here = whos_here.join(', ')
      args.body = "looks around and sees: #{whos_here}"
    when "/nick"
      args.to = args.nick
      args.action = true
      args.body = "needs to log out and log in again to change nicks"
    when "/join"
      args.to = args.nick
      args.action = true
      return Meteor.call 'getByName', {name: rest.trim()}, (error,result) ->
        if (not result?) and /^ringhunters$/i.test(rest.trim())
          result = {type:'general',object:_id:'0'}
        if error? or not result?
          args.body = "tried to join an unknown chat room"
          return Meteor.call 'newMessage', args
        hideMessageAlert()
        cleanupChat()
        joinRoom result.type, result.object._id, 0
    when "/msg", "/m"
      # find who it's to
      [to, rest] = rest.split(/\s+([^]*)/, 2)
      missingMessage = (not rest)
      while rest
        n = model.Nicks.findOne canon: model.canonical(to)
        break if n
        [extra, rest] = rest.split(/\s+([^]*)/, 2)
        to += ' ' + extra
      if n
        args.body = rest
        args.to = to
      else
        # error: unknown user
        # record this attempt as a PM to yourself
        args.to = args.nick
        args.body = "tried to /msg an UNKNOWN USER: #{message}"
        args.body = "tried to say nothing: #{message}" if missingMessage
        args.action = true
  Meteor.call 'newMessage', args # updates LastRead as a side-effect
  # for flicker prevention, we are currently not doing latency-compensation
  # on the newMessage call, which makes the below ineffective.  But leave
  # it here in case we turn latency compensation back on.
  Tracker.afterFlush -> scrollMessagesView()
  # make sure we're looking at the most recent messages
  if (+Session.get('timestamp'))
    share.Router.navigate "/chat/#{Session.get 'room_name'}", {trigger:true}
  return
Template.messages_input.events
  "keydown textarea": (event, template) ->
    # tab completion
    if event.which is 9 # tab
      event.preventDefault() # prevent tabbing away from input field
      $message = $ event.currentTarget
      message = $message.val()
      if message
        for present in whos_here_helper().fetch()
          n = model.Nicks.findOne(canon: present.nick)
          realname = if n then model.getTag(n, 'Real Name')
          re = new RegExp "^#{message}", "i"
          if re.test present.nick
            $message.val "#{present.nick}: "
          else if realname and re.test realname
            $message.val "#{realname}: "
          else if re.test "@#{present.nick}"
            $message.val "@#{present.nick} "
          else if realname and re.test "@#{realname}"
            $message.val "@#{realname} "
          else if re.test("/m #{present.nick}") or \
                  re.test("/msg #{present.nick}") or \
                  realname and (re.test("/m #{realname}") or \
                                re.test("/msg #{realname}"))
            $message.val "/msg #{present.nick} "
    # implicit submit on enter (but not shift-enter or ctrl-enter)
    return unless event.which is 13 and not (event.shiftKey or event.ctrlKey)
    event.preventDefault() # prevent insertion of enter
    $message = $ event.currentTarget
    message = $message.val()
    $message.val ""
    Template.messages_input.submit message


# alert for unread messages
$(document).on 'blur', '#messageInput', ->
  instachat.alertWhenUnreadMessages = true

$(document).on 'focus', '#messageInput', ->
  updateLastRead() if instachat.ready # skip during initial load
  instachat.alertWhenUnreadMessages = false
  hideMessageAlert()

updateLastRead = ->
  timestamp = (+Session.get('timestamp')) or Number.MAX_VALUE
  return unless timestamp is Number.MAX_VALUE # don't update if we're paged back
  lastMessage = model.Messages.findOne
    room_name: Session.get 'room_name'
  ,
    sort: [['timestamp','desc']]
  nick = Session.get 'nick'
  return unless lastMessage and nick
  Meteor.call 'updateLastRead',
    nick: nick
    room_name: Session.get 'room_name'
    timestamp: lastMessage.timestamp

hideMessageAlert = -> updateNotice 0, 0

Template.chat.onCreated ->
  this.autorun =>
    $("title").text("Chat: "+prettyRoomName())
  this.autorun =>
    instachat.keepalive?()
    updateLastRead() if isVisible() and instachat.ready

Template.chat.onRendered ->
  $(window).resize()
  share.ensureNick ->
    type = Session.get('type')
    id = Session.get('id')
    joinRoom type, id

startupChat = ->
  return if instachat.keepaliveInterval?
  instachat.keepalive = ->
    return unless Session.get('nick')
    Meteor.call "setPresence",
      nick: Session.get('nick')
      room_name: Session.get "room_name"
      present: true
      foreground: isVisible() # foreground/background tab status
      uuid: settings.CLIENT_UUID # identify this tab
  instachat.keepalive()
  # send a keep alive every N minutes
  instachat.keepaliveInterval = \
    Meteor.setInterval instachat.keepalive, (model.PRESENCE_KEEPALIVE_MINUTES*60*1000)

cleanupChat = ->
  try
    favicon.reset()
  if instachat.keepaliveInterval?
    Meteor.clearInterval instachat.keepaliveInterval
    instachat.keepalive = instachat.keepaliveInterval = undefined
  if Session.get('nick') and false # causes bouncing. just let it time out.
    Meteor.call "setPresence",
      nick: Session.get('nick')
      room_name: Session.get "room_name"
      present: false

Template.chat.onDestroyed ->
  hideMessageAlert()
  cleanupChat()
# window.unload is a bit spotty with async stuff, but we might as well try
$(window).unload -> cleanupChat()

# App startup
Meteor.startup ->
  return unless typeof Audio is 'function' # for phantomjs
  instachat.messageMentionSound = new Audio "/sound/Electro_-S_Bainbr-7955.wav"

updateNotice = do ->
  [lastUnread, lastMention] = [0, 0]
  (unread, mention) ->
    if mention > lastMention and instachat.ready
      instachat.messageMentionSound?.play?() unless Session.get "mute"
    # update title and favicon
    if mention > 0
      favicon.badge mention, {bgColor: '#00f'} if mention != lastMention
    else
      favicon.badge unread, {bgColor: '#000'} if unread != lastUnread
    ## XXX check instachat.ready and instachat.alertWhenUnreadMessages ?
    [lastUnread, lastMention] = [unread, mention]

Tracker.autorun ->
  pageWithChat = /^(chat|puzzle|round)$/.test Session.get('currentPage')
  nick = model.canonical(Session.get('nick') or '')
  room_name = Session.get 'room_name'
  unless pageWithChat and nick and room_name
    Session.set 'lastread', undefined
    return hideMessageAlert()
  # watch the last read and update the session (even if we're paged back)
  Meteor.subscribe 'lastread-for-nick', nick
  lastread = model.LastRead.findOne(nick: nick, room_name: room_name)
  unless lastread
    Session.set 'lastread', undefined
    return hideMessageAlert()
  Session.set 'lastread', lastread.timestamp
  # watch the unread messages (unless we're paged back)
  return hideMessageAlert() unless (+Session.get('timestamp')) is 0
  total_unread = 0
  total_mentions = 0
  update = -> false # ignore initial updates
  model.Messages.find
    room_name: room_name
    nick: $ne: nick
    timestamp: $gt: lastread.timestamp
  .observe
    added: (item) ->
      return if item.system
      total_unread++
      total_mentions++ if doesMentionNick item
      update()
    removed: (item) ->
      return if item.system
      total_unread--
      total_mentions-- if doesMentionNick item
      update()
    changed: (newItem, oldItem) ->
      unless oldItem.system
        total_unread--
        total_mentions-- if doesMentionNick oldItem
      unless newItem.system
        total_unread++
        total_mentions++ if doesMentionNick newItem
      update()
  # after initial query is processed, handle updates
  update = -> updateNotice total_unread, total_mentions
  update()

# evil hack to workaround scroll issues.
do ->
  f = ->
    return unless Session.equals('currentPage', 'chat')
    maybeScrollMessagesView()
  Meteor.setTimeout f, 5000

# exports
share.chat =
  favicon: favicon
  convertURLsToLinksAndImages: convertURLsToLinksAndImages
  startupChat: startupChat
  cleanupChat: cleanupChat
  hideMessageAlert: hideMessageAlert
  joinRoom: joinRoom
  # pagination helpers
  pageForTimestamp: pageForTimestamp
  messagesForPage: messagesForPage
  # for debugging
  instachat: instachat

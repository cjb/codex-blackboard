'use strict'
model = share.model # import
settings = share.settings # import

GENERAL_ROOM = 'Ringhunters'

Session.setDefault 'room_name', "general/0"
Session.setDefault 'nick'     , ($.cookie("nick") || "")
Session.setDefault 'mute'     , $.cookie("mute")
Session.setDefault 'type'     , 'general'
Session.setDefault 'id'       , '0'
Session.setDefault 'timestamp', 0

# Globals
instachat = {}
instachat["UTCOffset"] = new Date().getTimezoneOffset() * 60000
instachat["alertWhenUnreadMessages"] = false
instachat["messageAlertInterval"]    = undefined
instachat["unreadMessages"]          = 0
instachat["scrolledToBottom"]        = true

# Template Binding
Template.messages.room_name = -> Session.get('room_name')
Template.messages.timestamp = -> +Session.get('timestamp')
Template.messages.messages  = ->
  timestamp = (+Session.get('timestamp')) or Number.MAX_VALUE
  messages = model.Messages.find
    room_name: Session.get("room_name")
    timestamp: $lt: timestamp
  ,
    sort: [['timestamp',"desc"]]
    limit: model.MESSAGE_PAGE
  sameNick = do ->
    prevContext = null
    (m) ->
      thisContext = m.nick + (if m.to then "/#{m.to}" else "")
      thisContext = null if m.system or m.action
      result = thisContext? and (thisContext == prevContext)
      prevContext = thisContext
      return result
  for m, i in messages.fetch().reverse()
    first: ("/chat/#{Session.get 'room_name'}/#{m.timestamp}" if i is 0)
    followup: sameNick(m)
    message: m

Template.messages.email = ->
  cn = model.canonical(this.message.nick)
  n = model.Nicks.findOne canon: cn
  return model.getTag(n, 'Gravatar') or "#{cn}@#{settings.DEFAULT_HOST}"

Template.messages.body = ->
  body = this.message.body
  unless this.message.bodyIsHtml
    body = Handlebars._escape(body)
    body = body.replace(/\n|\r\n?/g, '<br/>')
    body = convertURLsToLinksAndImages(body, this.message._id)
    body = highlightNick(body) if doesMentionNick(this.message)
  new Handlebars.SafeString(body)

Template.messages.preserve
  ".inline-image[id]": (node) -> node.id
Template.messages.created = ->
  instachat.scrolledToBottom = true
  this.computation = Deps.autorun =>
    invalidator = =>
      this.sub1?.stop?()
      this.sub2?.stop?()
      this.sub3?.stop?()
      this.sub1 = this.sub2 = this.sub3 = null
      instachat.ready = false
      instachat.unreadMessages = 0
      hideMessageAlert()
    invalidator()
    room_name = Session.get 'room_name'
    return unless room_name
    this.sub1 = Meteor.subscribe 'presence-for-room', room_name
    nick = (if settings.BB_DISABLE_PM then null else Session.get 'nick') or null
    # re-enable private messages, but just in ringhunters (for codexbot)
    if settings.BB_DISABLE_PM and room_name is "general/0"
      nick = Session.get 'nick'
    timestamp = (+Session.get('timestamp')) or Number.MAX_VALUE
    ready = 0
    onReady = -> instachat.ready = true if (++ready) is 2
    if nick?
      this.sub2 = \
        Meteor.subscribe 'paged-messages-nick', nick, room_name, timestamp,
          onReady: onReady
    else
      onReady()
    this.sub3 = Meteor.subscribe 'paged-messages', room_name, timestamp,
      onReady: onReady
    Deps.onInvalidate invalidator
Template.messages.destroyed = ->
  this.computation.stop() # runs invalidation handler, too
Template.messages.rendered = ->
  scrollMessagesView() if instachat.scrolledToBottom

Template.chat_header.room_name = -> prettyRoomName()
Template.chat_header.whos_here = ->
  roomName = Session.get('type') + '/' + Session.get('id')
  return model.Presence.find {room_name: roomName}, {sort:["nick"]}

# Utility functions

regex_escape = (s) -> s.replace /[$-\/?[-^{|}]/g, '\\$&'

doesMentionNick = (doc, raw_nick=(Session.get 'nick')) ->
  return false unless raw_nick
  return false unless doc.body?
  return false if doc.system # system messages don't count as mentions
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

highlightNick = (html) -> "<span class=\"highlight-nick\">" + html + "</span>"

convertURLsToLinksAndImages = (html, id) ->
  linkOrLinkedImage = (url, id) ->
    inner = url
    if url.match(/.(png|jpg|jpeg|gif)$/i) and id?
      inner = "<img src='#{url}' class='inline-image' id='#{id}'>"
    "<a href='#{url}' target='_blank'>#{inner}</a>"
  count = 0
  html.replace /(http(s?):\/\/[^ ]+)/g, (url) ->
    linkOrLinkedImage url, "#{id}-#{count++}"

[isVisible, registerVisibilityChange] = (->
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
  callbacks = []
  register = (cb) -> callbacks.push cb
  isVisible = -> !(document[hidden] or false)
  onVisibilityChange = (->
    wasHidden = true
    (e) ->
      isHidden = !isVisible()
      return  if wasHidden is isHidden
      wasHidden = isHidden
      for cb in callbacks
        cb !isHidden
  )()
  document.addEventListener visibilityChange, onVisibilityChange, false
  return [isVisible, register]
)()

registerVisibilityChange ->
  instachat.keepalive?()

prettyRoomName = ->
  type = Session.get('type')
  id = Session.get('id')
  name = if type is "general" then GENERAL_ROOM else \
    model.Names.findOne(id)?.name
  return (name or "unknown")

joinRoom = (type, id) ->
  roomName = type + '/' + id
  # xxx: could record the room name in a set here.
  Session.set "room_name", roomName
  share.Router.goToChat(type, id, Session.get('timestamp'))
  scrollMessagesView()
  $("#messageInput").select()
  startupChat()

scrollMessagesView = ->
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
$("button.mute").live "click", ->
  if Session.get "mute"
    $.removeCookie "mute", {path:'/'}
  else
    $.cookie "mute", true, {expires: 365, path: '/'}

  Session.set "mute", $.cookie "mute"

# ensure that we stay stuck to bottom even after images load
$('.bb-message-body .inline-image').live 'load mouseenter', (event) ->
  scrollMessagesView() if instachat.scrolledToBottom

# unstick from bottom if the user manually scrolls
$(window).scroll (event) ->
  return unless Session.equals('currentPage', 'chat')
  # set to false, just in case older browser doesn't have scroll properties
  instachat.scrolledToBottom = false
  [body, html] = [document.body, document.documentElement]
  return unless html?.scrollTop? and html?.scrollHeight?
  return unless html?.clientHeight?
  [scrollPos, scrollMax] = [html.scrollTop+html.clientHeight, html.scrollHeight]
  atBottom = (scrollPos >= scrollMax)
  # firefox says that the HTML element is scrolling, not the body element...
  if html.scrollTopMax?
    atBottom = (html.scrollTop >= (html.scrollTopMax-1)) or atBottom
  instachat.scrolledToBottom = atBottom

# Form Interceptors
$("#joinRoom").live "submit", ->
  roomName = $("#roomName").val()
  if not roomName
    # reset to old room name
    $("#roomName").val prettyRoomName()
  # is this the general room?
  else if model.canonical(roomName) is model.canonical(GENERAL_ROOM)
    joinRoom "general", "0"
  else
    # try to find room as a group, round, or puzzle name
    n = model.Names.findOne canon: model.canonical(roomName)
    if n
      joinRoom n.type, n._id
    else
      # reset to old room name
      $("#roomName").val prettyRoomName()
  return false

Template.messages_input.hasNick = -> Session.get('nick') or false

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
      args.body = "should read <a href='http://wiki.codexian.us/index.php?title=Chat_System' target='_blank'>Chat System</a> on the wiki"
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
  instachat.scrolledToBottom = true
  Meteor.call 'newMessage', args
  # make sure we're looking at the most recent messages
  if (+Session.get('timestamp'))
    share.Router.navigate "/chat/#{Session.get 'room_name'}", {trigger:true}
  return
Template.messages_input.events
  "keydown textarea": (event, template) ->
    # tab completion
    if event.which is 9 # tab
      event.preventDefault() # prevent tabbing away from input field
      whos_here = Template.chat_header.whos_here().fetch()
      $message = $ event.currentTarget
      message = $message.val()
      if message
        for present in whos_here
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
$("#messageInput").live "blur", ->
  instachat.alertWhenUnreadMessages = true

$("#messageInput").live "focus", ->
  instachat.alertWhenUnreadMessages = false
  hideMessageAlert()
  instachat.unreadMessages = 0

showUnreadMessagesAlert = ->
  return if instachat.messageAlertInterval
  # we use window.setInterval here instead of Meteor.setInterval because
  # this is run in a reactive context (from autorun) and Meteor
  # will complain if you set intervals inside a reactive context because
  # it doesn't know how to cancel them.  That's okay -- we're doing the
  # cancellation ourself.  So use window.setInterval to go behind Meteor's back.
  instachat.messageAlertInterval = window.setInterval ->
    title = $("title")
    name = "Chat: "+prettyRoomName()
    if title.text() == name
      msg = if instachat.unreadMessages == 1 then "message" else "messages"
      title.text(instachat.unreadMessages + " new " + msg + " - " + name)
    else
      title.text(name)
  , 1000

hideMessageAlert = ->
  return unless instachat.messageAlertInterval
  window.clearInterval instachat.messageAlertInterval
  instachat.messageAlertInterval = undefined
  $("title").text("Chat: "+prettyRoomName())

unreadMessage = (doc)->
  return unless instachat.ready # don't ping until we're done loading messages
  unless Session.equals('nick', doc["nick"]) || doc.system || Session.get "mute"
    # only ping if message mentions you
    if doc.body?.indexOf(Session.get('nick')) >= 0 and not doc.bodyIsHtml
      instachat.unreadMessageSound.play()

  if instachat.alertWhenUnreadMessages
    instachat.unreadMessages += 1
    showUnreadMessagesAlert()


Template.chat.created = ->
  this.afterFirstRender = ->
    # created callback means that we've switched to chat, but
    # can't call ensureNick until after firstRender
    share.ensureNick ->
      type = Session.get('type')
      id = Session.get('id')
      joinRoom type, id

Template.chat.rendered = ->
  $("title").text("Chat: "+prettyRoomName())
  $(window).resize()
  this.afterFirstRender?()
  this.afterFirstRender = undefined

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
  if instachat.keepaliveInterval?
    Meteor.clearInterval instachat.keepaliveInterval
    instachat.keepalive = instachat.keepaliveInterval = undefined
  if Session.get('nick') and false # causes bouncing. just let it time out.
    Meteor.call "setPresence",
      nick: Session.get('nick')
      room_name: Session.get "room_name"
      present: false

Template.chat.destroyed = ->
  hideMessageAlert()
  cleanupChat()
# window.unload is a bit spotty with async stuff, but we might as well try
$(window).unload -> cleanupChat()

# App startup
Meteor.startup ->
  instachat.unreadMessageSound = new Audio "/sound/Electro_-S_Bainbr-7955.wav"

Deps.autorun ->
  unless Session.equals("currentPage", "chat") and \
         (+Session.get('timestamp')) is 0
    hideMessageAlert()
    return
  # the autorun magic *doesn't* tear down 'observe's
  # live query handle when room_name or currentPage changes (but it should!)
  # we need to handle that ourselves...
  handle = model.Messages.find
    room_name: Session.get("room_name")
  .observe
    added: (item) ->
      unreadMessage(item) unless item.system
  Deps.onInvalidate -> handle.stop()

# exports
share.chat =
  convertURLsToLinksAndImages: convertURLsToLinksAndImages
  startupChat: startupChat
  cleanupChat: cleanupChat
  hideMessageAlert: hideMessageAlert
  joinRoom: joinRoom

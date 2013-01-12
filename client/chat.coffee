GENERAL_ROOM = 'Ringhunters'

Session.set 'room_name', "general/0"
Session.set 'nick'     , ($.cookie("nick") || "")
Session.set 'mute'     , $.cookie("mute")
Session.set 'type'     , 'general'
Session.set 'id'       , '0'

# Globals
instachat = {}
instachat["UTCOffset"] = new Date().getTimezoneOffset() * 60000
instachat["alertWhenUnreadMessages"] = false
instachat["messageAlertInterval"]    = undefined
instachat["unreadMessages"]          = 0
instachat["scrolledToBottom"]        = true

# Collection Subscriptions
Meteor.autosubscribe ->
  return unless Session.equals("currentPage", "chat")
  room_name = Session.get 'room_name'
  return unless room_name
  nick = Session.get 'nick' or null
  timestamp = (+Session.get('timestamp')) or Number.MAX_VALUE
  Meteor.subscribe 'presence-for-room', room_name
  Meteor.subscribe 'paged-messages', nick, room_name, timestamp
  # we always subscribe to all-nicks... but otherwise we could subscribe to
  # nick-for-room or some such

Meteor.autosubscribe ->
  return unless Session.equals("currentPage", "chat")
  return unless (+Session.get('timestamp')) is 0
  # the autosubscribe magic will tear down 'observe's
  # live query handle when room_name or currentPage changes
  Messages.find
    room_name: Session.get("room_name")
  .observe
    added: (item) ->
      scrollMessagesView() if instachat.scrolledToBottom
      unreadMessage(item) unless item.system

# Template Binding
Template.messages.room_name = -> Session.get('room_name')
Template.messages.timestamp = -> +Session.get('timestamp')
Template.messages.messages  = ->
  timestamp = (+Session.get('timestamp')) or Number.MAX_VALUE
  messages = Messages.find
    room_name: Session.get("room_name")
    timestamp: $lt: timestamp
  ,
    sort: [['timestamp',"desc"]]
    limit: MESSAGE_PAGE
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
  cn = canonical(this.message.nick)
  n = Nicks.findOne canon: cn
  return getTag(n, 'Gravatar') or "#{cn}@#{DEFAULT_HOST}"

Template.messages.body = ->
  body = this.message.body
  unless this.message.bodyIsHtml
    body = Handlebars._escape(body)
    body = body.replace(/\n|\r\n?/g, '<br/>')
    body = convertURLsToLinksAndImages(body, this.message._id)
    body = highlightNick(body) unless this.message.system
  new Handlebars.SafeString(body)

Template.messages.preserve
  ".inline-image[id]": (node) -> node.id

Template.chat_header.room_name = -> prettyRoomName()
Template.chat_header.whos_here = ->
  roomName = Session.get('type') + '/' + Session.get('id')
  return Presence.find room_name: roomName

# Utility functions


convertURLsToLinksAndImages = (html, id) ->
  linkOrLinkedImage = (url, id) ->
    inner = url
    if url.match(/.(png|jpg|jpeg|gif)$/i)
      inner = "<img src='#{url}' class='inline-image' id='#{id}'>"
    "<a href='#{url}' target='_blank'>#{inner}</a>"
  count = 0
  html.replace /(http(s?):\/\/[^ ]+)/, (url) ->
    linkOrLinkedImage url, "#{id}-#{count++}"

highlightNick = (html) ->
  nickRE = new RegExp(Session.get("nick"))
  if html.match(nickRE)
    html = "<span class=\"highlight-nick\">" + html + "</span>"
  else
    html

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
    Names.findOne(id)?.name
  return (name or "unknown")

joinRoom = (type, id) ->
  roomName = type + '/' + id
  # xxx: could record the room name in a set here.
  Session.set "room_name", roomName
  Router.goToChat(type, id, Session.get('timestamp'))
  scrollMessagesView()
  $("#messageInput").select()
  instachat.keepalive = ->
    Meteor.call "setPresence"
      nick: Session.get('nick')
      room_name: Session.get "room_name"
      present: true
      foreground: isVisible() # foreground/background tab status
      uuid: CLIENT_UUID # identify this tab
  instachat.keepalive()
  # send a keep alive every N minutes
  instachat.keepaliveInterval = Meteor.setInterval instachat.keepalive, (PRESENCE_KEEPALIVE_MINUTES*60*1000)

scrollMessagesView = ->
  # using window.setTimeout here instead of Meteor.setTimeout because
  # scrollMessagesView is called inside a reactive context.  See the
  # comment in showUnreadMessagesAlert.
  instachat.scrolledToBottom = true
  window.setTimeout ->
    # first try using html5, then fallback to jquery
    last = document?.querySelector?('.bb-chat-messages > *:last-child')
    if last?.scrollIntoView?
      last.scrollIntoView()
    else
      $("body").scrollTo 'max'
    # the scroll handler below will reset scrolledToBottom to be false
    instachat.scrolledToBottom = true
  , 200

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
  # set to false, just in case older browser doesn't have scroll properties
  instachat.scrolledToBottom = false
  [body, html] = [document.body, document.body?.parentElement]
  return unless body?.scrollTop? and body?.scrollHeight?
  return unless html?.clientHeight?
  [scrollPos, scrollMax] = [body.scrollTop+html.clientHeight, body.scrollHeight]
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
  else if canonical(roomName) is canonical(GENERAL_ROOM)
    joinRoom "general", "0"
  else
    # try to find room as a group, round, or puzzle name
    n = Names.findOne canon: canonical(roomName)
    if n
      joinRoom n.type, n._id
    else
      # reset to old room name
      $("#roomName").val prettyRoomName()
  return false

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
    when "/msg"
      # find who it's to
      [to, rest] = rest.split(/\s+([^]*)/, 2)
      while rest
        n = Nicks.findOne canon: canonical(to)
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
        args.body = "tried to /msg an UNKNOWN USER: " + message
        args.action = true
  instachat.scrolledToBottom = true
  Meteor.call 'newMessage', args
  # make sure we're looking at the most recent messages
  if (+Session.get('timestamp'))
    Router.navigate "/chat/#{Session.get 'room_name'}", {trigger:true}
  return
Template.messages_input.events
  "keydown textarea": (event, template) ->
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
  # this is run in a reactive context (from autosubscribe) and Meteor
  # will complain if you set intervals inside a reactive context because
  # it doesn't know how to cancel them.  That's okay -- we're doing that
  # ourself.  So use window.setInterval to go behind Meteor's back.
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
  unless Session.equals('nick', doc["nick"]) || doc.system || Session.get "mute"
    instachat.unreadMessageSound.play()

  if instachat.alertWhenUnreadMessages
    instachat.unreadMessages += 1
    showUnreadMessagesAlert()


Template.chat.created = ->
  this.afterFirstRender = ->
    # created callback means that we've switched to chat, but
    # can't call ensureNick until after firstRender
    ensureNick ->
      type = Session.get('type')
      id = Session.get('id')
      joinRoom type, id

Template.chat.rendered = ->
  $("title").text("Chat: "+prettyRoomName())
  $(window).resize()
  this.afterFirstRender?()
  this.afterFirstRender = undefined

cleanupChat = ->
  if instachat.keepaliveInterval
    Meteor.clearInterval instachat.keepaliveInterval
    instachat.keepalive = instachat.keepaliveInterval = undefined
  Meteor.call "setPresence"
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

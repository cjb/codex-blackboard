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
instachat["messageAlertInterval"]    = null
instachat["unreadMessages"]          = 0

# Collection Subscriptions
""" XXX CSA commented out because we're autosubscribing still XXX
Meteor.subscribe 'rooms'

Meteor.autosubscribe ->
  room_name = Session.get 'room_name'
  Meteor.subscribe 'messages', room_name if room_name

Meteor.autosubscribe ->
  Messages.find
    room_name: Session.get("room_name")
  .observe
    added: (item) ->
      scrollMessagesView()
      unreadMessage(item) unless item.system
"""

# Template Binding
Template.messages.messages  = -> Messages.find(room_name: Session.get("room_name"))

Template.messages.pretty_ts = (timestamp) ->
  return unless timestamp
  d = new Date(timestamp)
  min = d.getMinutes()
  min = if min < 10 then "0" + min else min
  d.getHours() + ":" + min

Template.messages.body = ->
  body = this.body
  if (body.slice(0,4) == "/me ")
    body.slice(4)
  else
    body


Template.messages.nick = ->
  nick = this.nick
  if this.action
    "* " + nick
  else
    nick + ":"

Template.nickAndRoom.nick = -> Session.get "nick"

Template.nickAndRoom.room = -> prettyRoomName()

Template.nickAndRoom.volumeIcon = ->
  if Session.get "mute"
    "icon-volume-off"
  else
    "icon-volume-up"

Template.nickAndRoom.events
  "click .change-nick-link": (event, template) ->
    event.preventDefault()
    changeNick()

Template.nickModal.nick   = -> Session.get "nick"

# Utility functions
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
    collection(type)?.findOne(id)?.name
  return (name or "unknown")

joinRoom = (type, id) ->
  roomName = type + '/' + id
  # xxx: could record the room name in a set here.
  Session.set "room_name", roomName
  Router.goToChat(type, id)
  scrollMessagesView()
  $("#messageInput").select()
  instachat.keepalive = ->
    Meteor.call "setPresence"
      nick: Session.get('nick')
      room_name: Session.get "room_name"
      present: true
      foreground: isVisible() # foreground/background tab status
  instachat.keepalive()
  # send a keep alive every N minutes
  instachat.keepaliveInterval = Meteor.setInterval instachat.keepalive, (PRESENCE_KEEPALIVE_MINUTES*60*1000)

scrollMessagesView = ->
  Meteor.setTimeout ->
    $("#messagesInner").scrollTop 10000
  , 200

"""
UTCNow = ->
  now = new Date()
  Date.UTC(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours(), now.getMinutes(), now.getSeconds(), now.getMilliseconds())
"""

# Event Handlers
$("#mute").live "click", ->
  if Session.get "mute"
    $.cookie "mute", null
  else
    $.cookie "mute", true, {expires: 365}

  Session.set "mute", $.cookie "mute"

$(window).resize ->
  if Session.get("currentPage") is "chat"
    $("#chat-content").height $(window).height() -
      $("#chat-content").offset().top -
      $("#chat-footer").height()

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
    # try to find room as a puzzle name
    p = Puzzles.findOne(canon: canonical(roomName))
    if p
      joinRoom "puzzle", p._id
    else
      # try to find room as a round name
      r = Rounds.findOne(canon: canonical(roomName))
      if r
        joinRoom "round", r._id
      else
        # reset to old room name
        $("#roomName").val prettyRoomName()
  return false

$("#nickPick").live "submit", ->
  $warning = $(this).find ".warning"
  nick = $("#nickInput").val().replace(/^\s+|\s+$/g,"") #trim
  $warning.html ""
  if not nick || nick.length > 20
    $warning.html("Your nickname must be between 1 and 20 characters long!");
  else
    $.cookie "nick", nick, {expires: 365}
    Session.set "nick", nick
    $('#nickPickModal').modal 'hide'
    joinRoom Session.get('type'), Session.get('id')

  hideMessageAlert()
  return false

$("#messageForm").live "submit", (e) ->
  $message = $ "#messageInput"
  message  = $message.val()
  $message.val ""
  if message
    Meteor.call 'newMessage', {
      nick: Session.get "nick"
      body: message
      action: (message.slice(0,4) is "/me ")
      room_name: Session.get "room_name"}

  return false


# alert for unread messages
$("#messageInput").live "blur", ->
  instachat.alertWhenUnreadMessages = true

$("#messageInput").live "focus", ->
  instachat.alertWhenUnreadMessages = false
  hideMessageAlert()
  instachat.unreadMessages = 0

showUnreadMessagesAlert = ->
  return if instachat.messageAlertInterval
  instachat.messageAlertInterval = Meteor.setInterval ->
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
  Meteor.clearInterval instachat.messageAlertInterval
  instachat.messageAlertInterval = null
  $("title").text("Chat: "+prettyRoomName())

unreadMessage = (doc)->
  unless doc["nick"] == Session.get("nick") || Session.get "mute"
    instachat.unreadMessageSound.play()

  if instachat.alertWhenUnreadMessages
    instachat.unreadMessages += 1
    showUnreadMessagesAlert()


"""
## Router
InstaChatRouter = Backbone.Router.extend

  routes:
    "room/:roomName": "changeRoom"

  changeRoom: (roomName) ->
    $.cookie "room_name", roomName, {expires: 365}

  goToRoom: (roomName) ->
    this.navigate("/room/"+roomName, true)

Router = new InstaChatRouter()
Backbone.history.start {pushState: true}

#stubs
Meteor.methods
  newMessage: (args)->
    newMsg = {}
    newMsg["body"] = args.body
    newMsg["nick"] = args.nick if args.nick
    newMsg["system"] = args.system if args.system
    newMsg["room_name"] = args.room_name
    newMsg["timestamp"] = UTCNow()

    Messages.insert newMsg
    return true
"""

changeNick = (cb=(->)) ->
  $('#nickPickModal').one('hide', cb)
  $('#nickPickModal').modal keyboard: false, backdrop:"static"
  $('#nickInput').select()

ensureNick = (cb=(->)) ->
  if Session.get 'nick'
    cb()
  else if $.cookie('nick')
    Session.set 'nick', $.cookie('nick')
    cb()
  else
    changeNick cb

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
  this.afterFirstRender = null

cleanupChat = ->
  if instachat.keepaliveInterval
    Meteor.clearInterval instachat.keepaliveInterval
    instachat.keepalive = instachat.keepaliveInterval = null
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

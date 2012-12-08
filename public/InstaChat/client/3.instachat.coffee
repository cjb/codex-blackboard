Rooms       = new Meteor.Collection "rooms"
Messages    = new Meteor.Collection "messages"

Session.set 'room_name', null 
Session.set 'nick'     , ($.cookie("nick") || "")
Session.set 'mute'     , $.cookie("mute")

# Globals
instachat = {}
instachat["UTCOffset"] = new Date().getTimezoneOffset() * 60000
instachat["alertWhenUnreadMessages"] = false
instachat["messageAlertInterval"]    = null
instachat["unreadMessages"]          = 0

# Collection Subscriptions
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

# Template Binding
Template.messages.messages  = -> Messages.find()

Template.messages.pretty_ts = (timestamp) ->
  return unless timestamp
  d = new Date(timestamp)
  min = d.getMinutes()
  min = if min < 10 then "0" + min else min
  d.getHours() + ":" + min

Template.nickAndRoom.nick = -> Session.get "nick"

Template.nickAndRoom.room = -> Session.get "room_name"

Template.nickAndRoom.volumeIcon = ->
  if Session.get "mute"
    "icon-volume-off"
  else
    "icon-volume-up"

Template.nickModal.nick   = -> Session.get "nick"

# Utility functions
joinRoom = (roomName) ->
  room = Rooms.findOne name: roomName
  Rooms.insert name: roomName unless room
  Session.set "room_name", roomName
  $.cookie "room_name", roomName, {expires: 365}
  Router.goToRoom roomName
  scrollMessagesView()
  $("#messageInput").select()
  Meteor.call "newMessage"
    system: true
    body: Session.get("nick") + " just joined the room."
    room_name: Session.get "room_name"

scrollMessagesView = ->
  setTimeout ->
    $("#messagesInner").scrollTop 10000
  , 200

UTCNow = ->
  now = new Date()
  Date.UTC(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours(), now.getMinutes(), now.getSeconds(), now.getMilliseconds())


# Event Handlers
$("#mute").live "click", ->
  if Session.get "mute"
    $.cookie "mute", null
  else
    $.cookie "mute", true, {expires: 365}

  Session.set "mute", $.cookie "mute"
  
$(window).resize ->
  $("#content").height $(window).height() - 
    $("#content").offset().top - 
    $("#footer").height()

# Form Interceptors
$("#joinRoom").live "submit", ->
  roomName = $("#roomName").val()
  return unless roomName
  joinRoom roomName
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
    if $.cookie "room_name"
      joinRoom($.cookie("room_name"))
    else
      joinRoom('General')

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
  instachat.messageAlertInterval = window.setInterval ->
    title = $("title")
    if title.html() == "InstaChat"
      msg = if instachat.unreadMessages == 1 then "message" else "messages"
      title.html(instachat.unreadMessages + " new " + msg + " - InstaChat")
    else
      title.html("InstaChat")
  , 1000

hideMessageAlert = ->
  window.clearInterval instachat.messageAlertInterval
  instachat.messageAlertInterval = null
  window.setTimeout ->
    $("title").html("InstaChat")
  , 1000

unreadMessage = (doc)->
  unless doc["nick"] == Session.get("nick") || Session.get "mute"
    instachat.unreadMessageSound.play()

  if instachat.alertWhenUnreadMessages
    instachat.unreadMessages += 1
    showUnreadMessagesAlert()


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


# App startup
Meteor.startup ->
  instachat.unreadMessageSound = new Audio "/sound/Electro_-S_Bainbr-7955.wav"
  $(window).resize()
  $('#nickPickModal').modal keyboard: false, backdrop:"static"
  $('#nickInput').select()


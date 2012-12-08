# Rooms - {name: string}
Rooms = new Meteor.Collection "rooms"
Meteor.publish 'rooms', -> Rooms.find()

# Messages - {message:   String
#             username:  String
#             room_id:   String
#             created_at: Number}
Messages = new Meteor.Collection "messages"
Meteor.publish 'messages', (room_name) ->
  count = Messages.find({room_name:room_name}).count()
  skip  = if count > 150 then count - 150 else 0
  Messages.find({room_name: room_name}, {skip: skip})


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

UTCNow = ->
  now = new Date()
  Date.UTC(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours(), now.getMinutes(), now.getSeconds(), now.getMilliseconds())



Meteor.startup ->
  # remove all update/remove access from the client
  _.each ['Rooms', 'Messages'], (collection) ->
    _.each ['update', 'remove'], (method) ->
      Meteor.default_server.method_handlers['/' + collection + '/' + method] = ()->
        # nothing
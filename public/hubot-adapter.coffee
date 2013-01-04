Robot                                   = require '../robot'
Adapter                                 = require '../adapter'
{TextMessage,EnterMessage,LeaveMessage} = require '../message'

DDPClient = require("/home/cjb/meteor/node-ddp-client/lib/ddp-client")

class Blackboardbot extends Adapter
  run: ->
    self = @
    @robot.name = "codexbot"
    @ready = false

    initial_cb = ->
      @ready = true
      self.ddpclient.call "deleteNick", ["name": "codexbot", "tags": {}]
      self.ddpclient.call "newNick", ["name": "codexbot", "tags": {}]
      self.ddpclient.call "setPresence", [
        nick: "codexbot"
        room_name: "general/0"
        present: true
        foreground: true
      ]
      self.emit 'connected'

    update_cb = (data) ->
      if @ready
        if data.set.nick isnt "codexbot" and data.set.system is false and data.set.nick isnt ""
          self.receive new TextMessage data.set.nick, data.set.body

    # Connect to Meteor
    self.ddpclient = new DDPClient(host: "localhost", port: 3000)
    @robot.ddpclient = self.ddpclient
    self.ddpclient.connect ->
      console.log "connected!"
      self.ddpclient.subscribe "recent-messages", ["general/0"], initial_cb, update_cb, "messages"

  send: (user, strings...) ->
    self = @
    self.ddpclient.call "newMessage", [
      nick: "codexbot"
      body: "#{user}: #{strings}"
    ]

  reply: (user, strings...) ->
    self = @
    @send user, strings

  ddp_call: (method, args) ->
    self = @
    self.ddpclient.call method, args

exports.use = (robot) ->
  new Blackboardbot robot

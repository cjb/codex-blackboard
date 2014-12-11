# Description:
#   Hubot is very attentive (ping hubot)
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot ping - Reply with pong
#   hubot echo <text> - Reply back with <text>
#   hubot time - Reply with current time
#
# Author:
#   tapichu/cscott

phrases = [
  "Yes, master?"
  "At your service"
  "Unleash my strength"
  "I'm here. As always"
  "By your command"
  "Ready to work!"
  "Yes, milord?"
  "More work?"
  "Ready for action"
  "Orders?"
  "What do you need?"
  "Say the word"
  "Aye, my lord"
  "Locked and loaded"
  "Aye, sir?"
  "I await your command"
  "Your honor?"
  "Command me!"
  "At once"
  "What ails you?"
  "Yes, my firend?"
  "Is my aid required?"
  "Do you require my aid?"
  "My powers are ready"
  "It's hammer time!"
  "I'm your robot"
  "I'm on the job"
  "You're interrupting my calculations!"
  "What is your wish?"
  "How may I serve?"
  "At your call"
  "You require my assistance?"
  "What is it now?"
  "Hmm?"
  "I'm coming through!"
  "I'm here, mortal"
  "I'm ready and waiting"
  "Ah, at last"
  "I'm here"
  "Something need doing?"
]

secrets = [
  "You are my favorite user."
  "I know the answers to all the hunt puzzles."
  "Your mother liked you best."
  "There are no aliens in Area 51."
  "Somebody in this room has a crush on you."
  "You are of royal birth, but there was a mixup at the hospital."
  "One of KFC's eleven herbs and spices is: salt."
  "One of KFC's eleven herbs and spices is: pepper."
  "McDonald's \"special sauce\" is mostly mayonnaise, relish, and mustard."
]

regex_escape = (s) -> s.replace /[\^\\$*+?.()|{}\[\]\/]/g, '\\$&'

share.hubot.ping = (robot) ->

  name_regex = new RegExp("#{regex_escape robot.name}\\?$", "i")
  robot.hear name_regex, (msg) ->
    msg.reply msg.random phrases
    msg.finish()

  if robot.alias
    alias_regex = new RegExp("#{regex_escape robot.alias}\\?$", "i")
    robot.hear alias_regex, (msg) ->
      msg.reply msg.random phrases
      msg.finish()

  robot.commands.push 'bot ping - Reply with pong'
  robot.respond /PING$/i, (msg) ->
    msg.reply "PONG"
    msg.finish()

  robot.commands.push 'bot echo <text> - Reply back with <text>'
  robot.respond /ECHO (.*)$/i, (msg) ->
    msg.reply msg.match[1]
    msg.finish()

  robot.commands.push 'bot time - Reply with current time'
  robot.respond /TIME$/i, (msg) ->
    msg.reply "Server time is: #{new Date()}"
    msg.finish()

  robot.commands.push 'bot cry - Make the bot cry'
  robot.respond /CRY$/i, (msg) ->
    msg.emote "cries"
    msg.finish()

  robot.commands.push 'bot tell me a secret - Reply via private message'
  robot.respond /TELL ME A SECRET$/i, (msg) ->
    msg.priv msg.random secrets
    msg.finish()

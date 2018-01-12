# Description:
#   Get a meme from https://memegen.link


share.hubot.memes = (robot) ->
  robot.commands.push 'bot Y U NO <text> - Generates the Y U NO GUY with the bottom caption of <text>'
  robot.hear /Y U NO (.+)/i, (msg) ->
    memegen msg, 'yuno', '', msg.match[1]

  robot.commands.push 'bot Aliens guy <text> - Aliens guy weighs in on something'
  robot.hear /aliens guy (.+)/i, (msg) ->
    memegen msg, 'aag', '', msg.match[1]

  robot.commands.push 'bot <text> ALL the <things> - Generates ALL THE THINGS'
  robot.hear /(.*) (ALL the .*)/i, (msg) ->
    memegen msg, 'xy', msg.match[1], msg.match[2]

  robot.commands.push 'bot I don\'t always <something> but when i do <text> - Generates The Most Interesting man in the World'
  robot.hear /(I DON\'?T ALWAYS .*) (BUT WHEN I DO,? .*)/i, (msg) ->
    memegen msg, 'interesting', msg.match[1], msg.match[2]

  robot.commands.push 'bot <text> (SUCCESS|NAILED IT) - Generates success kid with the top caption of <text>'
  robot.hear /(.*)(SUCCESS|NAILED IT.*)/i, (msg) ->
    memegen msg, 'success', msg.match[1], msg.match[2]

  robot.commands.push 'bot <text> TOO DAMN <high> - Generates THE RENT IS TOO DAMN HIGH guy'
  robot.hear /(.*) (\w+\sTOO DAMN .*)/i, (msg) ->
    memegen msg, 'toohigh', msg.match[1], msg.match[2]

  robot.commands.push 'bot Not sure if <something> or <something else> - Generates a Futurama Fry meme'
  robot.hear /(NOT SURE IF .*) (OR .*)/i, (msg) ->
    memegen msg, 'fry', msg.match[1], msg.match[2]

  robot.commands.push 'bot Yo dawg <text> so <text> - Generates Yo Dawg'
  robot.hear /(YO DAWG .*) (SO .*)/i, (msg) ->
    memegen msg, 'yodawg', msg.match[1], msg.match[2]

  #robot.commands.push 'bot All your <text> are belong to <text> - All your <text> are belong to <text>'
  #robot.hear /(All your .*) (are belong to .*)/i, (msg) ->
  #  memegen msg, '', msg.match[1], msg.match[2]

  #robot.commands.push 'bot <text>, BITCH PLEASE <text> - Generates Yao Ming'
  #robot.hear /(.*)\s*BITCH PLEASE\s*(.*)/i, (msg) ->
  #  memegen msg, '', msg.match[1], msg.match[2]

  #robot.commands.push 'bot <text>, COURAGE <text> - Generates Courage Wolf'
  #robot.hear /(.*)\s*COURAGE\s*(.*)/i, (msg) ->
  #  memegen msg, '', msg.match[1], msg.match[2]

  robot.commands.push 'bot ONE DOES NOT SIMPLY <text> - Generates Boromir'
  robot.hear /ONE DOES NOT SIMPLY (.*)/i, (msg) ->
    memegen msg, 'mordor', 'ONE DOES NOT SIMPLY', msg.match[1]

  robot.commands.push 'bot IF YOU <text> GONNA HAVE A BAD TIME - Ski Instructor'
  robot.hear /(IF YOU .*\s)(.* GONNA HAVE A BAD TIME)/i, (msg) ->
    memegen msg, 'ski', msg.match[1], msg.match[2]

  #robot.commands.push 'bot IF YOU <text> TROLLFACE <text> - Troll Face'
  #robot.hear /(.*)TROLLFACE(.*)/i, (msg) ->
  #  memegen msg, 'dGAIFw', msg.match[1], msg.match[2]

  robot.commands.push 'bot If <text>, <word that can start a question> <text>? - Generates Philosoraptor'
  robot.hear /(IF .*), ((ARE|CAN|DO|DOES|HOW|IS|MAY|MIGHT|SHOULD|THEN|WHAT|WHEN|WHERE|WHICH|WHO|WHY|WILL|WON\'T|WOULD)[ \'N].*)/i, (msg) ->
    memegen msg, 'philosoraptor', msg.match[1], msg.match[2] + (if msg.match[2].search(/\?$/)==(-1) then '?' else '')

  #robot.commands.push 'bot <text>, AND IT\'S GONE - Bank Teller'
  #robot.hear /(.*)(AND IT\'S GONE.*)/i, (msg) ->
  #  memegen msg, 'uIZe3Q', msg.match[1], msg.match[2]

  robot.commands.push 'bot WHAT IF I TOLD YOU <text> - Morpheus What if I told you'
  robot.hear /WHAT IF I TOLD YOU (.*)/i, (msg) ->
    memegen msg, 'morpheus', 'WHAT IF I TOLD YOU', msg.match[1]

  #robot.commands.push 'bot WTF <text> - Picard WTF'
  #robot.hear /WTF (.*)/i, (msg) ->
  #  memegen msg, '', 'WTF', msg.match[1]

  robot.commands.push 'bot IF <text> THAT\'D BE GREAT - Generates Lumberg'
  robot.hear /(IF .*)(THAT\'D BE GREAT)/i, (msg) ->
    memegen msg, 'officespace', msg.match[1], msg.match[2]

  robot.commands.push 'bot MUCH <text> (SO|VERY) <text> - Generates Doge'
  robot.hear /(MUCH .*) ((SO|VERY) .*)/i, (msg) ->
    memegen msg, 'doge', msg.match[1], msg.match[2]

  robot.commands.push 'bot <text> EVERYWHERE - Generates Buzz Lightyear'
  robot.hear /(.*)(EVERYWHERE.*)/i, (msg) ->
    memegen msg, 'buzz', msg.match[1], msg.match[2]


memeGeneratorUrl = 'https://memegen.link'

# not a great conversion: no way to safely represent '~' or "'" eg
convTable =
  ' ': '-'
  '-': '--'
  '_': '__'
  '?': '~q'
  '%': '~p'
  '#': '~h'
  '/': '~s'
  '"': '\'\''

encode = (s) ->
   s.toLowerCase().replace /[-_ ?%\#/\"]/g, (c) -> convTable[c]

memegen = (msg, imageName, topText, botText) ->
  url = "#{memeGeneratorUrl}/#{imageName}/#{encode topText}/#{encode botText}.jpg"
  msg.send url

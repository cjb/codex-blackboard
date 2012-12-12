NAVBAR_HEIGHT = 73 # keep in sync with @navbar-height in blackboard.less

blackboard = {} # store page global state
blackboard.soundThreshold = 1*30*1000 # 30 secs

Meteor.startup ->
  blackboard.initialPageLoad = UTCNow()
  blackboard.newAnswerSound = new Audio "sound/that_was_easy.wav"
  # set up a persistent query so we can play the sound whenever we get a new
  # answer
  query = Puzzles.find $and: [ {answer: $ne: null}, {answer: $exists: true} ]
  query.observe
    added: (p, beforeIndex) ->
      # check the solved timestamp -- if it's within the last minute
      # (fudge factor), and the page isn't newly-loaded, play the sound.
      if p.solved and p.solved > (UTCNow() - blackboard.soundThreshold)
        if (UTCNow() - blackboard.initialPageLoad) > blackboard.soundThreshold
          blackboard.newAnswerSound.play()

Template.blackboard.lastupdates = ->
  LIMIT = 10
  ologs = OpLogs.find {}, \
        {sort: [["timestamp","desc"]], limit_BUG: LIMIT}
  # Meteor doesn't support the limit option yet.  So in a hacky workaround,
  # limit the collection client-side
  ologs = ologs.fetch().slice(0, LIMIT)
  # now look through the entries and collect similar logs
  # this way we can say "New puzzles: X, Y, and Z" instead of just "New Puzzle: Z"
  return '' unless ologs && ologs.length
  message = [ ologs[0] ]
  for ol in ologs[1..]
    if ol.message is message[0].message and ol.type is message[0].type
      message.push ol
    else
      break
  type = ''
  if message[0].id
    type = ' ' + pretty_collection(message[0].type) + \
      (if message.length > 1 then 's ' else ' ')
  desc = message.map (ol) ->
    return '' unless ol.id
    (collection(ol.type)?.findOne(ol.id)?.name or '')
  return {
    timestamp: message[0].timestamp
    message: message[0].message
    nick: message[0].nick
    type: type
    names: desc.join(',')
  }

Template.blackboard.lastchats = ->
  LIMIT = 2
  m = Messages.find {room_name: "general/0", system: false}, \
        {sort: [["timestamp","desc"]], limit_BUG: LIMIT}
  # Meteor doesn't support the limit option yet.  So in a hacky workaround,
  # limit the collection client-side
  m = m.fetch().slice(0, LIMIT)
  m.reverse()
  return m
Template.blackboard.pretty_ts = (ts) -> Template.messages.pretty_ts ts
Template.blackboard.roundgroups = -> RoundGroups.find {}
# XXX: the find operation on the next line is not order-preserving
Template.blackboard.rounds = -> Rounds.find _id: $in: this.rounds
Template.blackboard.rendered = ->
  #  page title
  $("title").text("Blackboard")
  $("#bb-sidebar").localScroll({ duration: 400 })
  $("body").scrollspy(target: "#bb-sidebar", offset: (NAVBAR_HEIGHT + 10))
  # update bootstrap "scroll spy" component when rounds list changes
  ss = $("body").data("scrollspy")
  ss.refresh()
  # hack to ensure first element is selected on first reload
  ss.activate(ss.targets[0]) if ss.targets.length
  ss.process()
  # affix side menu
  # XXX disabled because it doesn't play nice with narrow screens
  #$("#bb-sidebar > .bb-sidenav").affix()

Template.blackboard.events
  "click #bb-more-chats": (event, template) ->
    event.preventDefault()
    Router.goToChat "general", "0"

Template.blackboard_round.hasPuzzles = -> (this.puzzles.length > 0)
# XXX: the find operation on the next line is not order-preserving
Template.blackboard_round.puzzles = -> Puzzles.find _id: $in: this.puzzles
Template.blackboard_round.events
  "click .round-link": (event, template) ->
    event.preventDefault()
    round = template.data
    Router.goToRound round

Template.blackboard_puzzle.status = ->
  return (getTag this, "status") or ""
Template.blackboard_puzzle.whos_working = ->
  # note that server should automatically be pruning keepalives older than
  # 5 minutes, but we do some proactive pruning on client-side just in case
  # client drifts out of sync
  return Presence.find
    room_name: ("puzzle/"+this._id)
    timestamp: $gt: (UTCNow() - 15*60*100) # within a quarter hour

Template.blackboard_puzzle.pretty_ts = (timestamp, brief) ->
  duration = (Session.get('currentTime')||UTCNow()) - timestamp
  seconds = Math.floor(duration/1000)
  return "in the future" if seconds < -60
  return "just now" if seconds < 60
  [minutes, seconds] = [Math.floor(seconds/60), seconds % 60]
  [hours,   minutes] = [Math.floor(minutes/60), minutes % 60]
  [days,    hours  ] = [Math.floor(hours  /24), hours   % 24]
  [weeks,   days   ] = [Math.floor(days   / 7), days    % 7]
  ago = (s) -> (s.replace(/^\s+/,'') + " ago")
  s = ""
  s += " #{weeks} week" if weeks > 0
  s += "s" if weeks > 1
  return ago(s) if s and brief
  s += " #{days} day" if days > 0
  s += "s" if days > 1
  return ago(s) if s and brief
  s += " #{hours} hour" if hours > 0
  s += "s" if hours > 1
  return ago(s) if s and brief
  s += " #{minutes} minute" if minutes > 0
  s += "s" if minutes > 1
  return ago(s)

Template.blackboard_puzzle.events
  "click .puzzle-link": (event, template) ->
    event.preventDefault()
    puzzle = template.data
    Router.goToPuzzle puzzle

# Update 'currentTime' every minute or so to allow pretty_ts to magically
# update
Meteor.startup ->
  Meteor.setInterval ->
    Session.set "currentTime", UTCNow()
  , 60*1000

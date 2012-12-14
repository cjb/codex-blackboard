NAVBAR_HEIGHT = 73 # keep in sync with @navbar-height in blackboard.less
SOUND_THRESHOLD_MS = 30*1000 # 30 seconds

blackboard = {} # store page global state

Meteor.startup ->
  blackboard.initialPageLoad = UTCNow()
  blackboard.newAnswerSound = new Audio "sound/that_was_easy.wav"
  # set up a persistent query so we can play the sound whenever we get a new
  # answer
  # note that this observe 'leaks' -- we're not seeing it up/tearing it
  # down with the blackboard page, we're going to play the sound whatever
  # page the user is currently on.  This is "fun".  Trust us...
  Meteor.subscribe 'newly-answered-puzzles'
  query = Puzzles.find $and: [ {answer: $ne: null}, {answer: $exists: true} ]
  query.observe
    added: (p, beforeIndex) ->
      # check the solved timestamp -- if it's within the last minute
      # (fudge factor), and the page isn't newly-loaded, play the sound.
      if p.solved and p.solved > (UTCNow() - SOUND_THRESHOLD_MS)
        if (UTCNow() - blackboard.initialPageLoad) > SOUND_THRESHOLD_MS
          unless Session.get 'mute'
            blackboard.newAnswerSound.play()

Template.blackboard.volumeIcon = ->
  Template.nickAndRoom.volumeIcon()
Template.blackboard.sessionNick = -> Session.get 'nick'
Template.blackboard.canEdit = -> Session.get 'canEdit'

############## operation log in header ####################
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
  return {
    timestamp: message[0].timestamp
    message: message[0].message + type
    nick: message[0].nick
    objects: ({type:m.type,id:m.id} for m in message)
  }

Meteor.autosubscribe ->
  return unless Session.get("currentPage") is "blackboard"
  Meteor.subscribe 'recent-oplogs'

############## chat log in header ####################
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

Meteor.autosubscribe ->
  return unless Session.get("currentPage") is "blackboard"
  Meteor.subscribe 'recent-messages', 'general/0'

############## groups, rounds, and puzzles ####################
Template.blackboard.roundgroups = -> RoundGroups.find {}, sort: ["created"]
# the following is a map() instead of a direct find() to preserve order
Template.blackboard.rounds = ->
  ({
    round_num: 1+index+this.round_start
    round: Rounds.findOne(id)
    rX: "r#{1+index+this.round_start}"
   } for id, index in this.rounds)
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
  # tooltips
  $('#bb-sidebar .nav > li > a').tooltip placement: 'right'
  $('#bb-tables .bb-puzzle .puzzle-name > a').tooltip placement: 'left'
  # 'canEdit' radio buttons
  setCanEdit (Session.get('canEdit') and Session.get('nick'))

setCanEdit = (canEdit) ->
  Session.set 'canEdit', if canEdit then true else null
  $('.bb-buttonbar input:radio[name=editable]').val([
        if canEdit then 'true' else 'false'
  ])

Template.blackboard.events
  "click .canEdit-true": (event, template) ->
    setCanEdit true
    event.preventDefault()
  "click .canEdit-false": (event, template) ->
    setCanEdit false
    event.preventDefault()
  "click .logout": (event, template) ->
    setCanEdit false
    Session.set 'nick', null
    $.cookie 'nick', null
    event.preventDefault()

Template.blackboard_round.hasPuzzles = -> (this.round?.puzzles?.length > 0)
# the following is a map() instead of a direct find() to preserve order
Template.blackboard_round.puzzles = ->
  ({
    round_num: this.round_num
    puzzle_num: 1 + index
    puzzle: Puzzles.findOne(id)
    rXpY: "r#{this.round_num}p#{1+index}"
   } for id, index in this.round.puzzles)

Template.blackboard_puzzle.status = ->
  return (getTag this.puzzle, "status") or ""
Template.blackboard_puzzle.whos_working = ->
  return Presence.find
    room_name: ("puzzles/"+this.puzzle?._id)

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

# Subscribe to all group, round, and puzzle information
Meteor.autosubscribe ->
  return unless Session.get("currentPage") is "blackboard"
  Meteor.subscribe 'all-roundgroups'
  Meteor.subscribe 'all-rounds'
  Meteor.subscribe 'all-puzzles'
  # also subscribe to all presence information
  Meteor.subscribe 'all-presence'

# Update 'currentTime' every minute or so to allow pretty_ts to magically
# update
Meteor.startup ->
  Meteor.setInterval ->
    Session.set "currentTime", UTCNow()
  , 60*1000

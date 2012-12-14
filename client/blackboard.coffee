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

Template.blackboard.canEdit = -> Session.get 'canEdit'

############## groups, rounds, and puzzles ####################
Template.blackboard.roundgroups = -> RoundGroups.find {}, sort: ["created"]
# the following is a map() instead of a direct find() to preserve order
Template.blackboard.rounds = ->
  ({
    round_num: 1+index+this.round_start
    round: Rounds.findOne(id) or { _id: id, name: Names.findOne(id)?.name }
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

Template.blackboard_round.hasPuzzles = -> (this.round?.puzzles?.length > 0)
# the following is a map() instead of a direct find() to preserve order
Template.blackboard_round.puzzles = ->
  ({
    round_num: this.round_num
    puzzle_num: 1 + index
    puzzle: Puzzles.findOne(id) or { _id: id }
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

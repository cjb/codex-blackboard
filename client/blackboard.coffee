NAVBAR_HEIGHT = 73 # keep in sync with @navbar-height in blackboard.less

Meteor.startup ->
  blackboard.newAnswerSound = new Audio "sound/that_was_easy.wav"

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
    type = (switch message[0].type
      when 'puzzle' then ' puzzle'
      when 'round' then ' round'
      when 'roundgroup' then ' round group'
      else ' unknown item') + (if message.length > 1 then 's ' else ' ')
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
Template.blackboard_round.puzzles = -> Puzzles.find _id: $in: this.puzzles
Template.blackboard_round.events
  "click .round-link": (event, template) ->
    event.preventDefault()
    round = template.data
    Router.goToRound round

Template.blackboard_puzzle.status = ->
  return (getTag this, "status") or ""
Template.blackboard_puzzle.whos_working = ->
  # XXX look at chat logs?
  return ""
Template.blackboard_puzzle.last_update = ->
  if this.solved
    "solved " + Template.messages.pretty_ts(this.solved)
  else
    "added " + Template.messages.pretty_ts(this.created)
Template.blackboard_puzzle.events
  "click .puzzle-link": (event, template) ->
    event.preventDefault()
    puzzle = template.data
    Router.goToPuzzle puzzle

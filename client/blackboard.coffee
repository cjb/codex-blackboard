NAVBAR_HEIGHT = 73 # keep in sync with @navbar-height in blackboard.less

Meteor.startup ->
  blackboard.newAnswerSound = new Audio "sound/that_was_easy.wav"

Template.blackboard.lastupdates = ->
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
Template.blackboard.rendered = ->
  #  page title
  $("title").text("Blackboard")

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
  # look at various timestamps
  return ""
Template.blackboard_puzzle.events
  "click .puzzle-link": (event, template) ->
    event.preventDefault()
    puzzle = template.data
    Router.goToPuzzle puzzle

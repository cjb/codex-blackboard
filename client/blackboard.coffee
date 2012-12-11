Meteor.startup ->
  blackboard.newAnswerSound = new Audio "sound/that_was_easy.wav"

Template.blackboard.roundgroups = -> RoundGroups.find {}
Template.blackboard.rounds = -> Rounds.find _id: $in: this.rounds
Template.blackboard.rendered = ->
  $("body").scrollspy(target: "#bb-sidebar", offset: (81+10))
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
  # look at various timestamps
  return ""
Template.blackboard_puzzle.events
  "click .puzzle-link": (event, template) ->
    event.preventDefault()
    puzzle = template.data
    Router.goToPuzzle puzzle

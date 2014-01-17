'use strict'
model = share.model # import
settings = share.settings # import

Meteor.startup ->
  if typeof Audio is 'function' # for phantomjs
    newCallInSound = new Audio "sound/new_callin.wav"
  # note that this observe 'leaks'; that's ok, the set of callins is small
  Deps.autorun ->
    sub = Meteor.subscribe 'callins'
    return unless sub.ready() # reactive, will re-execute when ready
    initial = true
    model.CallIns.find({}).observe
      added: (doc) ->
        return if initial
        console.log 'ding dong'
        unless Session.get 'mute'
          newCallInSound?.play?()
    initial = false

Template.callins.callins = ->
  model.CallIns.find {},
    sort: [["created","asc"]]

Template.callins.created = ->
  this.afterFirstRender = -> share.ensureNick()

Template.callins.rendered = ->
  $("title").text("Answer queue")
  this.afterFirstRender?()
  this.afterFirstRender = undefined

Template.callin_row.created = ->
  this.get_callin_id = (event) ->
    $(event.currentTarget).closest('*[data-bbedit]').attr('data-bbedit')

Template.callin_row.sessionNick = -> Session.get 'nick'

Template.callin_row.lastAttempt = (puzzle_id) ->
  p = if puzzle_id then model.Puzzles.findOne(puzzle_id)
  return null unless p? and p.incorrectAnswers?.length > 0
  attempts = p.incorrectAnswers[..]
  attempts.sort (a,b) -> a.timestamp - b.timestamp
  attempts[attempts.length - 1]

Template.callin_row.events
  "click .bb-callin-correct": (event, template) ->
     Meteor.call 'correctCallIn',
       id: template.get_callin_id(event)
       who: Session.get('nick')

  "click .bb-callin-incorrect": (event, template) ->
     Meteor.call 'incorrectCallIn',
       id: template.get_callin_id(event)
       who: Session.get('nick')

  "click .bb-callin-cancel": (event, template) ->
     Meteor.call 'cancelCallIn',
       id: template.get_callin_id(event)
       who: Session.get('nick')

Deps.autorun ->
  return unless Session.equals("currentPage", "callins")
  Meteor.subscribe 'callins'
  return if settings.BB_SUB_ALL
  Meteor.subscribe 'all-roundsandpuzzles'

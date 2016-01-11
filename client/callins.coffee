'use strict'
model = share.model # import
settings = share.settings # import

Meteor.startup ->
  if typeof Audio is 'function' # for phantomjs
    newCallInSound = new Audio "sound/new_callin.wav"
  # note that this observe 'leaks'; that's ok, the set of callins is small
  Tracker.autorun ->
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

Template.callins.onCreated ->
  this.get_quip_id = (event) ->
    $(event.currentTarget).closest('*[data-bbquip]').attr('data-bbquip')
  this.autorun =>
    return unless Session.equals("currentPage", "callins")
    this.subscribe 'callins'
    this.subscribe 'quips'
    return if settings.BB_SUB_ALL
    this.subscribe 'all-roundsandpuzzles'

Template.callins.helpers
  callins: ->
    model.CallIns.find {},
      sort: [["created","asc"]]
  quips: ->
    # We may want to make this a special limited subscription
    # (rather than having to subscribe to all quips)
    model.Quips.find {},
      sort: [["last_used","asc"],["created","asc"]]
      limit: 5
  quipAddUrl: ->
    share.Router.urlFor 'quips', 'new'

Template.callins.onRendered ->
  $("title").text("Answer queue")
  share.ensureNick()

Template.callins.events
  "click .bb-addquip-btn": (event, template) ->
     share.Router.goTo "quips", "new"
  "click .bb-quip-next": (event, template) ->
    Meteor.call 'useQuip',
      id: template.get_quip_id(event)
      who: Session.get('nick')
  "click .bb-quip-remove": (event, template) ->
    Meteor.call 'removeQuip',
      id: template.get_quip_id(event)
      who: Session.get('nick')

Template.callin_row.onCreated ->
  this.get_callin_id = (event) ->
    $(event.currentTarget).closest('*[data-bbedit]').attr('data-bbedit')

Template.callin_row.helpers
  sessionNick: -> Session.get 'nick'
  lastAttempt: (type, target) ->
    p = if target then model.collection(type).findOne(target)
    return null unless p? and p.incorrectAnswers?.length > 0
    attempts = p.incorrectAnswers[..]
    attempts.sort (a,b) -> a.timestamp - b.timestamp
    attempts[attempts.length - 1]
  hunt_link: (type, target) ->
    p = if target then model.collection(type).findOne(target)
    p?.link

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

  "change .bb-submitted-to-hq": (event, template) ->
     checked = !!event.currentTarget.checked
     Meteor.call 'setField',
       type: 'callins'
       object: template.get_callin_id(event)
       fields: submitted_to_hq: checked
       who: Session.get('nick')

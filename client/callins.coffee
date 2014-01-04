'use strict'
model = share.model # import
settings = share.settings # import

Template.callins.callins = ->
  callins = model.CallIns.find {},
    sort: [["created","asc"]]

Template.callins.created = ->
  this.get_callin_id = (event) ->
    return $(event.currentTarget).closest('*[data-bbedit]').attr('data-bbedit')

Template.callins.rendered = ->
  $("title").text("Answer queue")

Template.callins.events
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

'use strict'
model = share.model # import
settings = share.settings # import

Template.callins.callins = ->
  callins = model.CallIns.find {},
    sort: [["created","asc"]]

Template.callins.created = ->
  this.get_callin = (event) ->
    return $(event.currentTarget).closest('*[data-bbedit]').attr('data-bbedit')

Template.callins.rendered = ->
  $("title").text("Answer queue")

Template.callins.events
  "click .bb-callin-correct": (event, template) ->
     args = {id: template.get_callin(event)}
     Meteor.call 'correctCallin', args

  "click .bb-callin-incorrect": (event, template) ->
     args = {id: template.get_callin(event)}
     Meteor.call 'incorrectCallin', args

  "click .bb-callin-cancel": (event, template) ->
     args = {id: template.get_callin(event)}
     Meteor.call 'correctCallin', args

Deps.autorun ->
  return unless Session.equals("currentPage", "callins")
  Meteor.subscribe 'callins'

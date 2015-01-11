'use strict'
model = share.model # import

Template.quip.helpers
  idIsNew: -> Session.equals 'id', 'new'
  quip: ->
    id = Session.get 'id'
    if id is 'new' then null else model.Quips.findOne id
  recentQuips: ->
    model.Quips.find({},{sort:[['created','desc']], limit: 10})

Template.quip.events
  "click .bb-addquip-btn": (event, template) ->
     share.Router.goTo "quips", "new"
  "click .bb-quip-delete-btn": (event, template) ->
     share.ensureNick =>
       Meteor.call "removeQuip", {
         id: Session.get 'id'
         who: Session.get 'nick'
       }, (error, result) ->
         unless error?
           share.Router.goTo "quips", "new"

  "keydown form.bb-add-new-quip": (event, template) ->
     # implicit submit on enter.
     return unless event.which is 13 and not (event.shiftKey or event.ctrlKey)
     event.preventDefault() # prevent insertion of enter
     $(event.currentTarget).submit()
  "submit form.bb-add-new-quip": (event, template) ->
     event.preventDefault() # ensure we don't actually navigate
     share.ensureNick =>
       $textarea = $('textarea', event.currentTarget)
       text = $textarea.val()
       $textarea.val ''
       q = Meteor.call 'newQuip', {
         text: text
         who: Session.get 'nick'
       }, (error, result) ->
         unless error?
           share.Router.goTo "quips", result._id

Tracker.autorun ->
  return unless Session.equals("currentPage", "quip")
  Meteor.subscribe 'quips'

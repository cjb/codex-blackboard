'use strict'
model = share.model # import

Template.quip.helpers
  idIsNew: -> Session.equals 'id', 'new'
  quip: ->
    id = Session.get 'id'
    if id is 'new' then null else model.Quips.findOne id
  recentQuips: ->
    model.Quips.find({},{sort:[['created','desc']], limit: 10})
  canEdit: -> Session.get 'nick'

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

  "click .bb-editable": (event, template) ->
    value = share.find_bbedit(event).join('/')
    share.ensureNick =>
      # note that we rely on 'blur' on old field (which triggers ok or cancel)
      # happening before 'click' on new field
      Session.set 'editing', value
Template.quip.events share.okCancelEvents('.bb-editable input',
  ok: (text, evt) ->
    # find the data-bbedit specification for this field
    edit = $(evt.currentTarget).closest('*[data-bbedit]').attr('data-bbedit')
    [type, id, rest...] = edit.split('/')
    # strip leading/trailing whitespace from text (cancel if text is empty)
    text = text.replace /^\s+|\s+$/, ''
    processQuipEdit[type]?(text, id, rest...) if text
    Session.set 'editing', undefined # done editing this
  cancel: (evt) ->
    Session.set 'editing', undefined # not editing anything anymore
)
processQuipEdit =
  quips: (text, id, field) ->
    processQuipEdit["quips_#{field}"]?(text, id)
  quips_text: (text, id) ->
    return unless text
    Meteor.call 'setField',
      type: 'quips'
      object: id
      who: Session.get 'nick'
      fields: text: text

Tracker.autorun ->
  return unless Session.equals("currentPage", "quip")
  $("title").text("Quips")
  Meteor.subscribe 'quips'

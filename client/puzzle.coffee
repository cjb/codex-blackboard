'use strict'
model = share.model # import
settings = share.settings # import

Template.puzzle.helpers
  data: ->
    r = {}
    puzzle = r.puzzle = model.Puzzles.findOne Session.get("id")
    round = r.round = model.Rounds.findOne puzzles: puzzle?._id
    group = r.group = model.RoundGroups.findOne rounds: round?._id
    r.puzzle_num = 1 + (round?.puzzles or []).indexOf(puzzle?._id)
    r.round_num = 1 + group?.round_start + \
                  (group?.rounds or []).indexOf(round?._id)
    r.hunt_year = settings.HUNT_YEAR
    return r

Template.puzzle.onCreated ->
  $('html').addClass('fullHeight')
  share.chat.startupChat()
  this.autorun =>
    # set page title
    type = Session.get('type')
    id = Session.get('id')
    name = model.collection(type)?.findOne(id)?.name or id
    $("title").text("Puzzle: "+name)
  # presumably we also want to subscribe to the puzzle's chat room
  # and presence information at some point.
  this.autorun =>
    return if settings.BB_SUB_ALL
    return unless Session.equals("type", "puzzles")
    puzzle_id = Session.get('id')
    return unless puzzle_id
    this.subscribe 'puzzle-by-id', puzzle_id
    this.subscribe 'round-for-puzzle', puzzle_id
    round = model.Rounds.findOne puzzles: puzzle_id
    return unless round
    this.subscribe 'roundgroup-for-round', round._id

Template.puzzle.onRendered ->
  $('html').addClass('fullHeight')
  share.Splitter.vsize.set()
# XXX we originally did this every time anything in the template was changed:
#  share.Splitter.vsize.set() unless share.Splitter.vsize.manualResized
# with the new `onRendered` callback semantics this isn't possible.  Maybe we
# don't really need it?
Template.puzzle.onDestroyed ->
  $('html').removeClass('fullHeight')
  share.chat.cleanupChat()

Template.puzzle.events
  "click .bb-drive-select": (event, template) ->
    event.preventDefault()
    drive = this.puzzle.drive
    return unless drive
    docsView = new google.picker.DocsView()\
      .setIncludeFolders(true).setParent(drive)
    new google.picker.PickerBuilder()\
      .setDeveloperKey('AIzaSyC5h171Bt3FrLlSYDur-RbvTXwgxXYgUv0')\
      .addView(docsView)\
      .enableFeature(google.picker.Feature.NAV_HIDDEN)\
      .setCallback(pickerCallback)\
      .build().setVisible true
  "click .bb-drive-upload": (event, template) ->
    event.preventDefault()
    drive = this.puzzle.drive
    return unless drive
    share.uploadToDriveFolder drive, (docs) -> console.log docs
  "mousedown .bb-splitter-handle": (e,t) -> share.Splitter.handleEvent(e,t)

Template.puzzle_correct_answer.helpers
  tag: (name) -> (model.getTag this, name) or ''

Template.puzzle_callin_modal.events
  "click .bb-callin-btn": (event, template) ->
    share.ensureNick =>
      template.$('input:text').val('')
      template.$('input:checked').val([])
      template.$('.modal').modal show: true
      template.$('input:text').focus()
  "click .bb-callin-submit": (event, template) ->
    event.preventDefault() # don't reload page
    answer = template.$('.bb-callin-answer').val()
    return unless answer
    backsolve = ''
    if template.$('input:checked[value="provided"]').val() is 'provided'
      backsolve += "provided "
    if template.$('input:checked[value="backsolve"]').val() is 'backsolve'
      backsolve += "backsolved "
    if backsolve
      backsolve += "answer "
    if /answer|backsolve|provided|for|puzzle|^[\'\"]/i.test(answer)
      answer = '"' + answer.replace(/\"/g,'\\"') + '"'
    Meteor.call "newMessage",
      body: "bot: call in #{backsolve}#{answer.toUpperCase()}"
      nick: Session.get 'nick'
      room_name: "#{Session.get 'type'}/#{Session.get 'id'}"
    template.$('.modal').modal 'hide'

# A simple callback implementation.
pickerCallback = (data) ->
  url = "nothing"
  if data[google.picker.Response.ACTION] is google.picker.Action.PICKED
    doc = data[google.picker.Response.DOCUMENTS][0]
    url = doc[google.picker.Document.URL]
  message = "You picked: " + url
  console.log message, data

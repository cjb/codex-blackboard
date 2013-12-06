Template.puzzle.data = ->
  r = {}
  puzzle = r.puzzle = Puzzles.findOne Session.get("id")
  round = r.round = Rounds.findOne puzzles: puzzle?._id
  group = r.group = RoundGroups.findOne rounds: round?._id
  r.puzzle_num = 1 + (round?.puzzles or []).indexOf(puzzle?._id)
  r.round_num = 1 + group?.round_start + \
                (group?.rounds or []).indexOf(round?._id)
  return r
Template.puzzle.created = ->
  $('html').addClass('fullHeight')
  startupChat()
  this.afterFirstRender = ->
    Splitter.vsize.set()
Template.puzzle.rendered = ->
  $('html').addClass('fullHeight')
  this.afterFirstRender?()
  this.afterFirstRender = null
  # set page title
  type = Session.get('type')
  id = Session.get('id')
  name = collection(type)?.findOne(id)?.name or id
  $("title").text("Puzzle: "+name)
Template.puzzle.destroyed = ->
  $('html').removeClass('fullHeight')
  cleanupChat()

Template.puzzle.preserve
  "iframe[src]": (node) -> node.src

Template.puzzle.events
  "click .bb-drive-select": (event, template) ->
    event.preventDefault()
    drive = this.puzzle.drive
    return unless drive
    docsView = new google.picker.DocsView()\
      .setIncludeFolders(true).setParent(drive)
    new google.picker.PickerBuilder()\
      .setAppId('365816747654.apps.googleusercontent.com')\
      .addView(docsView)\
      .enableFeature(google.picker.Feature.NAV_HIDDEN)\
      .setCallback(pickerCallback)\
      .build().setVisible true
  "click .bb-drive-upload": (event, template) ->
    event.preventDefault()
    drive = this.puzzle.drive
    return unless drive
    uploadToDriveFolder drive, (docs) -> console.log docs
  "mousedown .bb-splitter-handle": (e,t) -> Splitter.handleEvent(e,t)

# presumably we also want to subscribe to the puzzle's chat room
# and presence information at some point.
Meteor.autorun ->
  return if BB_SUB_ALL
  return unless Session.equals("type", "puzzles")
  puzzle_id = Session.get('id')
  return unless puzzle_id
  Meteor.subscribe 'puzzle-by-id', puzzle_id
  Meteor.subscribe 'round-for-puzzle', puzzle_id
  round = Rounds.findOne puzzles: puzzle_id
  return unless round
  Meteor.subscribe 'roundgroup-for-round', round._id

# A simple callback implementation.
pickerCallback = (data) ->
  url = "nothing"
  if data[google.picker.Response.ACTION] is google.picker.Action.PICKED
    doc = data[google.picker.Response.DOCUMENTS][0]
    url = doc[google.picker.Document.URL]
  message = "You picked: " + url
  console.log message, data

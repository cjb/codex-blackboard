Template.round.data = ->
  r = {}
  round = r.round = Rounds.findOne Session.get("id")
  group = r.group = RoundGroups.findOne rounds: round?._id
  r.round_num = 1 + group?.round_start + \
                (group?.rounds or []).indexOf(round?._id)
  r.puzzles = ((Puzzles.findOne(p) or {_id:p}) for p in (round?.puzzles or []))
  return r
Template.round.created = ->
  $('html').addClass('fullHeight')
  startupChat()
  this.afterFirstRender = ->
    Splitter.vsize.set()
Template.round.rendered = ->
  $('html').addClass('fullHeight')
  this.afterFirstRender?()
  this.afterFirstRender = null
  # set page title
  type = Session.get('type')
  id = Session.get('id')
  name = collection(type)?.findOne(id)?.name or id
  $("title").text("Round: "+name)
Template.round.destroyed = ->
  $('html').removeClass('fullHeight')
  cleanupChat()

Template.round.preserve
  "iframe[src]": (node) -> node.src

Template.round.events
  "click .bb-drive-upload": (event, template) ->
    event.preventDefault()
    drive = this.round.drive
    return unless drive
    uploadToDriveFolder drive, (docs) -> console.log docs
  "mousedown .bb-splitter-handle": (e,t) -> Splitter.handleEvent(e, t)

# presumably we also want to subscribe to the round's chat room
# and presence information at some point.
Meteor.autorun ->
  return if BB_SUB_ALL
  return unless Session.equals("type", "rounds")
  round_id = Session.get('id')
  return unless round_id
  Meteor.subscribe 'round-by-id', round_id
  Meteor.subscribe 'roundgroup-for-round', round_id
  r = Rounds.findOne round_id
  return unless r
  for p in r.puzzles
    Meteor.subscribe 'puzzle-by-id', p

## Helper function for linking puzzles in rounds to the hunt-running site
updateHuntLinks = (round_prefix) ->
  # round prefix is something like "http://www.coinheist.com/indiana/"
  Rounds.update Session.get("id"), $set: link: round_prefix
  Rounds.findOne(Session.get("id")).puzzles \
    .map((p) -> Puzzles.findOne p).filter((p) -> not p.link ) \
    .forEach (p) ->
      Puzzles.update p._id, $set: link: "#{round_prefix}#{p.canon}"

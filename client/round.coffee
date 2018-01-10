'use strict'
model = share.model # import
settings = share.settings # import

Template.round.helpers
  data: ->
    r = {}
    round = r.round = model.Rounds.findOne Session.get("id")
    group = r.group = model.RoundGroups.findOne rounds: round?._id
    r.round_num = 1 + group?.round_start + \
                  (group?.rounds or []).indexOf(round?._id)
    r.puzzles = ((model.Puzzles.findOne(p) or {_id:p}) \
      for p in (round?.puzzles or []))
    r.hunt_year = settings.HUNT_YEAR
    r.stuck = model.isStuck round
    return r
  tag: (name) ->
    return (model.getTag this, name) or ''
Template.round.onCreated ->
  $('html').addClass('fullHeight')
  share.chat.startupChat()
  this.autorun =>
    # set page title
    type = Session.get('type')
    id = Session.get('id')
    name = model.collection(type)?.findOne(id)?.name or id
    $("title").text("Round: "+name)
  # presumably we also want to subscribe to the round's chat room
  # and presence information at some point.
  this.autorun =>
    return if settings.BB_SUB_ALL
    return unless Session.equals("type", "rounds")
    round_id = Session.get('id')
    return unless round_id
    this.subscribe 'round-by-id', round_id
    this.subscribe 'roundgroup-for-round', round_id
    r = model.Rounds.findOne round_id
    return unless r
    for p in r.puzzles
      this.subscribe 'puzzle-by-id', p

Template.round.onRendered ->
  $('html').addClass('fullHeight')
  share.Splitter.vsize.set()
# XXX we originally did this every time anything in the template was changed:
#  share.Splitter.vsize.set() unless share.Splitter.vsize.manualResized
# with the new `onRendered` callback semantics this isn't possible.  Maybe we
# don't really need it?
Template.round.onDestroyed ->
  $('html').removeClass('fullHeight')
  share.chat.cleanupChat()

Template.round.events
  "click .bb-drive-upload": (event, template) ->
    event.preventDefault()
    drive = this.round.drive
    return unless drive
    share.uploadToDriveFolder drive, (docs) -> console.log docs
  "mousedown .bb-splitter-handle": (e,t) -> share.Splitter.handleEvent(e, t)

## Helper function for linking puzzles in rounds to the hunt-running site
share.updateHuntLinks = (round_prefix, puzzle_prefix) ->
  # round prefix is something like "http://www.coinheist.com/indiana/"
  puzzle_prefix ?= round_prefix
  model.Rounds.update Session.get("id"), $set: link: round_prefix
  model.Rounds.findOne(Session.get("id")).puzzles \
    .map((p) -> model.Puzzles.findOne p).filter((p) -> not p.link ) \
    .forEach (p) ->
      model.Puzzles.update p._id, $set: link: "#{puzzle_prefix}#{p.canon}"

Template.round.data = ->
  r = {}
  round = r.round = Rounds.findOne Session.get("id")
  group = r.group = RoundGroups.findOne rounds: round?._id
  r.round_num = 1 + group?.round_start + \
                (group?.rounds or []).indexOf(round?._id)
  return r
Template.round.rendered = ->
  type = Session.get('type')
  id = Session.get('id')
  name = collection(type)?.findOne(id)?.name
  $("title").text("Round: "+name)
Template.round.events
  "click .bb-drive-upload": (event, template) ->
    event.preventDefault()
    drive = this.round.drive
    return unless drive
    uploadToDriveFolder drive, (docs) -> console.log docs

# presumably we also want to subscribe to the round's chat room
# and presence information at some point.
Meteor.autosubscribe ->
  return unless Session.equals("type", "rounds")
  round_id = Session.get('id')
  return unless round_id
  Meteor.subscribe 'round-by-id', round_id
  Meteor.subscribe 'roundgroup-for-round', round_id

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
  "click .chat-link": (event, template) ->
    event.preventDefault()
    Router.goToChat "rounds", Session.get('id')

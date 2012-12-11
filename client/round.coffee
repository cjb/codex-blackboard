Template.round.round = -> Rounds.findOne(Session.get "id")
Template.round.rendered = ->
  type = Session.get('type')
  id = Session.get('id')
  name = collection(type)?.findOne(id)?.name
  $("title").text("Round: "+name)
Template.round.events
  "click .chat-link": (event, template) ->
    event.preventDefault()
    Router.goToChat "round", Session.get('id')

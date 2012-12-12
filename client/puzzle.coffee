Template.puzzle.puzzle = -> Puzzles.findOne(Session.get "id")
Template.puzzle.rendered = ->
  type = Session.get('type')
  id = Session.get('id')
  name = collection(type)?.findOne(id)?.name
  $("title").text("Puzzle: "+name)
Template.puzzle.events
  "click .chat-link": (event, template) ->
    event.preventDefault()
    Router.goToChat "puzzles", Session.get('id')

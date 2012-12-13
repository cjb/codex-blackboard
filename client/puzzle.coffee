Template.puzzle.data = ->
  r = {}
  puzzle = r.puzzle = Puzzles.findOne Session.get("id")
  round = r.round = Rounds.findOne puzzles: puzzle?._id
  group = r.group = RoundGroups.findOne rounds: round?._id
  r.puzzle_num = 1 + (round?.puzzles or []).indexOf(puzzle?._id)
  r.round_num = 1 + group?.round_start + \
                (group?.rounds or []).indexOf(round?._id)
  return r
Template.puzzle.rendered = ->
  type = Session.get('type')
  id = Session.get('id')
  name = collection(type)?.findOne(id)?.name
  $("title").text("Puzzle: "+name)
Template.puzzle.events
  "click .chat-link": (event, template) ->
    event.preventDefault()
    Router.goToChat "puzzles", Session.get('id')

# presumably we also want to subscribe to the puzzle's chat room
# and presence information at some point.
Meteor.autosubscribe ->
  return unless Session.get("currentPage") is "puzzle"
  puzzle_id = Session.get('id')
  return unless puzzle_id
  Meteor.subscribe 'puzzle-by-id', puzzle_id
  Meteor.subscribe 'round-for-puzzle', puzzle_id
  round = Rounds.findOne puzzles: puzzle_id
  return unless round
  Meteor.subscribe 'roundgroup-for-round', round._id

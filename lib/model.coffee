# Blackboard -- data model
# Loaded on both the client and the server

# Each round is represented by a document in the Rounds collection:
#   id: round id, integer
#   order: display order if different to id, integer
#   name: string
#   created: timestamp
Rounds = new Meteor.Collection "rounds"

# Each round contains puzzles:
#   id: puzzle id, integer
#   order: display order if different to id, integer
#   title: string
#   answer: string
Puzzles = new Meteor.Collection "puzzles"


NAVBAR_HEIGHT = 73 # keep in sync with @navbar-height in blackboard.less
SOUND_THRESHOLD_MS = 30*1000 # 30 seconds

blackboard = {} # store page global state

Meteor.startup ->
  blackboard.newAnswerSound = new Audio "sound/that_was_easy.wav"
  # set up a persistent query so we can play the sound whenever we get a new
  # answer
  # note that this observe 'leaks' -- we're not setting it up/tearing it
  # down with the blackboard page, we're going to play the sound whatever
  # page the user is currently on.  This is "fun".  Trust us...
  Meteor.subscribe 'last-answered-puzzle'
  # ignore added; that's just the startup state.  Watch 'changed'
  LastAnswer.find({}).observe
    changed: (doc, atIndex, oldDoc) ->
      return if doc.puzzle is oldDoc.puzzle # answer changed, not really new
      console.log 'that was easy', doc, oldDoc
      unless Session.get 'mute'
        blackboard.newAnswerSound.play()

# Returns an event map that handles the "escape" and "return" keys and
# "blur" events on a text input (given by selector) and interprets them
# as "ok" or "cancel".
# (Borrowed from Meteor 'todos' example.)
okCancelEvents = (selector, callbacks) ->
  ok = callbacks.ok or (->)
  cancel = callbacks.cancel or (->)
  evspec = ("#{ev} #{selector}" for ev in ['keyup','keydown','focusout'])
  events = {}
  events[evspec.join(', ')] = (evt) ->
    if evt.type is "keydown" and evt.which is 27
      # escape = cancel
      cancel.call this, evt
    else if evt.type is "keyup" and evt.which is 13 or evt.type is "focusout"
      # blur/return/enter = ok/submit if non-empty
      value = String(evt.target.value or "")
      if value
        ok.call this, value, evt
      else
        cancel.call this, evt
  events

######### general properties of the blackboard page ###########
Template.blackboard.sortReverse = -> Session.get 'sortReverse'

############## groups, rounds, and puzzles ####################
Template.blackboard.roundgroups = ->
  dir = if Session.get 'sortReverse' then 'desc' else 'asc'
  RoundGroups.find {}, sort: [["created", dir]]
# the following is a map() instead of a direct find() to preserve order
Template.blackboard.rounds = ->
  r = ({
    round_num: 1+index+this.round_start
    round: Rounds.findOne(id) or { _id: id, name: Names.findOne(id)?.name }
    rX: "r#{1+index+this.round_start}"
    num_puzzles: (Rounds.findOne(id)?.puzzles or []).length
    num_solved: (p for p in (Rounds.findOne(id)?.puzzles or []) when \
                 Puzzles.findOne(p)?.answer).length
   } for id, index in this.rounds)
   r.reverse() if Session.get 'sortReverse'
   return r
Template.blackboard.preserve ['#bb-sidebar']
Template.blackboard.created = ->
  this.afterFirstRender = ->
    $("#bb-sidebar").localScroll({ duration: 400, lazy: true })
    $("body").scrollspy(target: "#bb-sidebar", offset: (NAVBAR_HEIGHT + 10))
  this.find_bbedit = (event) ->
     edit = $(event.currentTarget).closest('*[data-bbedit]').attr('data-bbedit')
     return edit.split('/')
Template.blackboard.rendered = ->
  this.afterFirstRender?()
  this.afterFirstRender = null
  #  page title
  $("title").text("Codex Puzzle Blackboard")
  # update bootstrap "scroll spy" component when rounds list changes
  ss = $("body").data("scrollspy")
  ss.refresh()
  # hack to ensure first element is selected on first reload
  ss.activate(ss.targets[0]) if ss.targets.length
  ss.process()
  # affix side menu
  # XXX disabled because it doesn't play nice with narrow screens
  #$("#bb-sidebar > .bb-sidenav").affix()
  # tooltips
  $('#bb-sidebar .nav > li > a').tooltip placement: 'right'
  $('#bb-tables .bb-puzzle .puzzle-name > a').tooltip placement: 'left'
Template.blackboard.events
  "click .bb-sort-order button": (event, template) ->
     reverse = $(event.currentTarget).attr('data-sortReverse') is 'true'
     Session.set 'sortReverse', reverse or undefined
  "click .bb-add-round-group": (event, template) ->
     alertify.prompt "Name of new round group:", (e,str) ->
        return unless e # bail if cancelled
        Meteor.call 'newRoundGroup', { name: str, who: Session.get('nick') }
  "click .bb-roundgroup-buttons .bb-add-round": (event, template) ->
     [type, id, rest...] = template.find_bbedit(event)
     who = Session.get('nick')
     alertify.prompt "Name of new round:", (e,str) ->
        return unless e # bail if cancelled
        Meteor.call 'newRound', { name: str, who: who }, (error,r)->
          throw error if error
          Meteor.call 'addRoundToGroup', {round: r._id, group: id, who: who}
  "click .bb-round-buttons .bb-add-puzzle": (event, template) ->
     [type, id, rest...] = template.find_bbedit(event)
     who = Session.get('nick')
     alertify.prompt "Name of new puzzle:", (e,str) ->
        return unless e # bail if cancelled
        Meteor.call 'newPuzzle', { name: str, who: who }, (error,p)->
          throw error if error
          Meteor.call 'addPuzzleToRound', {puzzle: p._id, round: id, who: who}
  "click .bb-add-tag": (event, template) ->
     [type, id, rest...] = template.find_bbedit(event)
     who = Session.get('nick')
     alertify.prompt "Name of new tag:", (e,str) ->
        return unless e # bail if cancelled
        Meteor.call 'setTag', type, id, str, '', who
  "click .bb-move-up, click .bb-move-down": (event, template) ->
     [type, id, rest...] = template.find_bbedit(event)
     up = event.currentTarget.classList.contains('bb-move-up')
     # flip direction if sort order is inverted
     up = (!up) if (Session.get 'sortReverse') and type isnt 'puzzles'
     method = if up then 'moveUp' else 'moveDown'
     Meteor.call method, {type:type, id:id, who:Session.get('nick')}
  "click .bb-canEdit .bb-delete-icon": (event, template) ->
     event.stopPropagation() # keep .bb-editable from being processed!
     [type, id, rest...] = template.find_bbedit(event)
     message = "Are you sure you want to delete "
     if (type is'tags') or (rest[0] is 'title')
       message += "this #{pretty_collection(type)}?"
     else
       message += "the #{rest[0]} of this #{pretty_collection(type)}?"
     confirmationDialog
       ok_button: 'Yes, delete it'
       no_button: 'No, cancel'
       message: message
       ok: ->
         processBlackboardEdit[type]?(null, id, rest...) # process delete
  "click .bb-canEdit .bb-editable": (event, template) ->
     # note that we rely on 'blur' on old field (which triggers ok or cancel)
     # happening before 'click' on new field
     Session.set 'editing', template.find_bbedit(event).join('/')
Template.blackboard.events okCancelEvents('.bb-editable input',
  ok: (text, evt) ->
     # find the data-bbedit specification for this field
     edit = $(evt.currentTarget).closest('*[data-bbedit]').attr('data-bbedit')
     [type, id, rest...] = edit.split('/')
     # strip leading/trailing whitespace from text (cancel if text is empty)
     text = text.replace /^\s+|\s+$/, ''
     processBlackboardEdit[type]?(text, id, rest...) if text
     Session.set 'editing', undefined # done editing this
  cancel: (evt) ->
     Session.set 'editing', undefined # not editing anything anymore
)
processBlackboardEdit =
  tags: (text, id, canon, field) ->
    field = 'name' if text is null # special case for delete of status tag
    processBlackboardEdit["tags_#{field}"]?(text, id, canon)
  puzzles: (text, id, field) ->
    processBlackboardEdit["puzzles_#{field}"]?(text, id)
  rounds: (text, id, field) ->
    processBlackboardEdit["rounds_#{field}"]?(text, id)
  roundgroups: (text, id, field) ->
    processBlackboardEdit["roundgroups_#{field}"]?(text, id)
  puzzles_title: (text, id) ->
    if text is null # delete puzzle
      Meteor.call 'deletePuzzle', {id:id, who:Session.get('nick')}
    else
      Meteor.call 'renamePuzzle', {id:id, name:text, who:Session.get('nick')}
  rounds_title: (text, id) ->
    if text is null # delete round
      Meteor.call 'deleteRound', {id:id, who:Session.get('nick')}
    else
      Meteor.call 'renameRound', {id:id, name:text, who:Session.get('nick')}
  roundgroups_title: (text, id) ->
    if text is null # delete roundgroup
      Meteor.call 'deleteRoundGroup', {id:id, who:Session.get('nick')}
    else
      Meteor.call 'renameRoundGroup', {id:id,name:text,who:Session.get('nick')}
  puzzles_answer: (text, id) ->
    who = Session.get 'nick'
    if text is null
      Meteor.call 'deleteAnswer', {puzzle:id, who:who}
    else
      Meteor.call 'setAnswer', {puzzle:id, answer:text, who:who}
  tags_name: (text, id, canon) ->
    who = Session.get('nick')
    n = Names.findOne(id)
    if text is null # delete tag
      return Meteor.call 'deleteTag', n.type, id, canon, who
    tags = collection(n.type).findOne(id).tags
    t = (tag for tag in tags when tag.canon is canon)[0]
    Meteor.call 'setTag', n.type, id, text, t.value, who, (error,result) ->
      if (t.canon isnt canonical(text)) and (not error)
        Meteor.call 'deleteTag', n.type, id, t.name, who
  tags_value: (text, id, canon) ->
    n = Names.findOne(id)
    tags = collection(n.type).findOne(id).tags
    t = (tag for tag in tags when tag.canon is canon)[0]
    # special case for 'status' tag, which might not previously exist
    for special in ['Status', 'Meta Answer']
      if (not t) and canon is canonical(special)
        t =
          name: special
          canon: canonical(special)
          value: ''
    # set tag (overwriting previous value)
    Meteor.call 'setTag', n.type, id, t.name, text, Session.get('nick')

Template.blackboard_round.hasPuzzles = -> (this.round?.puzzles?.length > 0)
# the following is a map() instead of a direct find() to preserve order
Template.blackboard_round.puzzles = ->
  ({
    round_num: this.round_num
    puzzle_num: 1 + index
    puzzle: Puzzles.findOne(id) or { _id: id }
    rXpY: "r#{this.round_num}p#{1+index}"
   } for id, index in this.round.puzzles)
Template.blackboard_round.tag = (name) ->
  return (getTag this.round, name) or ''
Template.blackboard_round.whos_working = ->
  return Presence.find
    room_name: ("rounds/"+this.round?._id)
  , sort: ["nick"]

Template.blackboard_puzzle.tag = (name) ->
  return (getTag this.puzzle, name) or ''
Template.blackboard_puzzle.whos_working = ->
  return Presence.find
    room_name: ("puzzles/"+this.puzzle?._id)
  , sort: ["nick"]

Template.blackboard_puzzle_tags.tags = (id) ->
  isRound = ('puzzles' of this)
  { id: id, name: t.name, canon: t.canon, value: t.value } \
    for t in (this?.tags or []) when not \
        (Session.equals('currentPage', 'blackboard') and \
         (t.canon is 'status' or (isRound and t.canon is 'meta_answer')))
Template.blackboard_tags.tags = Template.blackboard_puzzle_tags.tags

# Subscribe to all group, round, and puzzle information
Meteor.autosubscribe ->
  return unless Session.equals("currentPage", "blackboard")
  Meteor.subscribe 'all-presence'
  return if BB_SUB_ALL
  Meteor.subscribe 'all-roundgroups'
  Meteor.subscribe 'all-rounds'
  Meteor.subscribe 'all-puzzles'

# Update 'currentTime' every minute or so to allow pretty_ts to magically
# update
Meteor.startup ->
  Meteor.setInterval ->
    Session.set "currentTime", UTCNow()
  , 60*1000

'use strict'
model = share.model # import
settings = share.settings # import

NAVBAR_HEIGHT = 73 # keep in sync with @navbar-height in blackboard.less
SOUND_THRESHOLD_MS = 30*1000 # 30 seconds

blackboard = {} # store page global state

Meteor.startup ->
  if typeof Audio is 'function' # for phantomjs
    blackboard.newAnswerSound = new Audio "sound/that_was_easy.wav"
  # set up a persistent query so we can play the sound whenever we get a new
  # answer
  # note that this observe 'leaks' -- we're not setting it up/tearing it
  # down with the blackboard page, we're going to play the sound whatever
  # page the user is currently on.  This is "fun".  Trust us...
  Meteor.subscribe 'last-answered-puzzle'
  # ignore added; that's just the startup state.  Watch 'changed'
  model.LastAnswer.find({}).observe
    changed: (doc, oldDoc) ->
      return unless doc.target? # 'no recent puzzle was solved'
      return if doc.target is oldDoc.target # answer changed, not really new
      console.log 'that was easy', doc, oldDoc
      unless Session.get 'mute'
        blackboard.newAnswerSound?.play?()

# Returns an event map that handles the "escape" and "return" keys and
# "blur" events on a text input (given by selector) and interprets them
# as "ok" or "cancel".
# (Borrowed from Meteor 'todos' example.)
okCancelEvents = share.okCancelEvents = (selector, callbacks) ->
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
['sortReverse','hideSolved','hideRoundsSolvedMeta','hideStatus','compactMode'].forEach (name) ->
  Session.setDefault name, $.cookie(name)
compactMode = ->
  editing = (Session.get 'nick') and (Session.get 'canEdit')
  (Session.get 'compactMode') and not editing
Template.blackboard.helpers
  sortReverse: -> Session.get 'sortReverse'
  hideSolved: -> Session.get 'hideSolved'
  hideRoundsSolvedMeta: -> Session.get 'hideRoundsSolvedMeta'
  hideStatus: -> Session.get 'hideStatus'
  compactMode: compactMode

############## groups, rounds, and puzzles ####################
Template.blackboard.helpers
  roundgroups: ->
    dir = if Session.get 'sortReverse' then 'desc' else 'asc'
    model.RoundGroups.find {}, sort: [["created", dir]]
  # the following is a map() instead of a direct find() to preserve order
  rounds: ->
    r = ({
      round_num: 1+index+this.round_start
      round: (model.Rounds.findOne(id) or \
              {_id: id, name: model.Names.findOne(id)?.name, puzzles: []})
      rX: "r#{1+index+this.round_start}"
      num_puzzles: (model.Rounds.findOne(id)?.puzzles or []).length
      num_solved: (p for p in (model.Rounds.findOne(id)?.puzzles or []) when \
                   model.Puzzles.findOne(p)?.solved?).length
    } for id, index in this.rounds)
    r.reverse() if Session.get 'sortReverse'
    return r

Template.blackboard_status_grid.helpers
  roundgroups: ->
    dir = if Session.get 'sortReverse' then 'desc' else 'asc'
    model.RoundGroups.find {}, sort: [["created", dir]]
  # the following is a map() instead of a direct find() to preserve order
  rounds: ->
    r = ({
      round_num: 1+index+this.round_start
      round: (model.Rounds.findOne(id) or \
              {_id: id, name: model.Names.findOne(id)?.name, puzzles: []})
      rX: "r#{1+index+this.round_start}"
      num_puzzles: (model.Rounds.findOne(id)?.puzzles or []).length
    } for id, index in this.rounds)
    return r
  puzzles: ->
    p = ({
      round_num: this.x_num
      puzzle_num: 1 + index
      puzzle: model.Puzzles.findOne(id) or { _id: id }
      rXpY: "r#{this.round_num}p#{1+index}"
      pY: "p#{1+index}"
    } for id, index in this.round?.puzzles)
    return p

Template.nick_presence.helpers
  email: ->
    cn = share.model.canonical(this.nick)
    n = share.model.Nicks.findOne canon: cn
    return share.model.getTag(n, 'Gravatar') or "#{cn}@#{settings.DEFAULT_HOST}"

share.find_bbedit = (event) ->
  edit = $(event.currentTarget).closest('*[data-bbedit]').attr('data-bbedit')
  return edit.split('/')

Template.blackboard.onRendered ->
  $("#bb-sidebar").localScroll({ duration: 400, lazy: true })
  $("body").scrollspy(target: "#bb-sidebar", offset: (NAVBAR_HEIGHT + 10))
  ss = $("body").data("scrollspy")
  # hack to ensure first element is selected on first reload
  ss.activate(ss.targets[0]) if ss.targets.length
  ss.process()
  #  page title
  $("title").text("Codex Puzzle Blackboard")
  # affix side menu
  # XXX disabled because it doesn't play nice with narrow screens
  #$("#bb-sidebar > .bb-sidenav").affix()
  # tooltips
  $('#bb-sidebar .nav > li > a').tooltip placement: 'right'
  $('#bb-tables .bb-puzzle .puzzle-name > a').tooltip placement: 'left'
  # see the global 'updateScrollSpy' helper for details on how
  # we update scrollspy when the rounds list changes
doBoolean = (name, newVal) ->
  Session.set name, newVal
  $.cookie name, (newVal or ''),  {expires: 365, path: '/'}
Template.blackboard.events
  "click .bb-sort-order button": (event, template) ->
    reverse = $(event.currentTarget).attr('data-sortReverse') is 'true'
    doBoolean 'sortReverse', reverse
  "change .bb-hide-solved input": (event, template) ->
    doBoolean 'hideSolved', event.target.checked
  "change .bb-hide-rounds-solved-meta input": (event, template) ->
    doBoolean 'hideRoundsSolvedMeta', event.target.checked
  "change .bb-compact-mode input": (event, template) ->
    doBoolean 'compactMode', event.target.checked
  "click .bb-hide-status": (event, template) ->
    doBoolean 'hideStatus', !(Session.get 'hideStatus')
  "click .bb-add-round-group": (event, template) ->
    alertify.prompt "Name of new round group:", (e,str) ->
      return unless e # bail if cancelled
      Meteor.call 'newRoundGroup', { name: str, who: Session.get('nick') }
  "click .bb-roundgroup-buttons .bb-add-round": (event, template) ->
    [type, id, rest...] = share.find_bbedit(event)
    who = Session.get('nick')
    alertify.prompt "Name of new round:", (e,str) ->
      return unless e # bail if cancelled
      Meteor.call 'newRound', { name: str, who: who }, (error,r)->
        throw error if error
        Meteor.call 'addRoundToGroup', {round: r._id, group: id, who: who}
  "click .bb-round-buttons .bb-add-puzzle": (event, template) ->
    [type, id, rest...] = share.find_bbedit(event)
    who = Session.get('nick')
    alertify.prompt "Name of new puzzle:", (e,str) ->
      return unless e # bail if cancelled
      Meteor.call 'newPuzzle', { name: str, who: who }, (error,p)->
        throw error if error
        Meteor.call 'addPuzzleToRound', {puzzle: p._id, round: id, who: who}
  "click .bb-add-tag": (event, template) ->
    [type, id, rest...] = share.find_bbedit(event)
    who = Session.get('nick')
    alertify.prompt "Name of new tag:", (e,str) ->
      return unless e # bail if cancelled
      Meteor.call 'setTag', {type:type, object:id, name:str, value:'', who:who}
  "click .bb-move-up, click .bb-move-down": (event, template) ->
    [type, id, rest...] = share.find_bbedit(event)
    up = event.currentTarget.classList.contains('bb-move-up')
    # flip direction if sort order is inverted
    up = (!up) if (Session.get 'sortReverse') and type isnt 'puzzles'
    method = if up then 'moveUp' else 'moveDown'
    Meteor.call method, {type:type, id:id, who:Session.get('nick')}
  "click .bb-canEdit .bb-delete-icon": (event, template) ->
    event.stopPropagation() # keep .bb-editable from being processed!
    [type, id, rest...] = share.find_bbedit(event)
    message = "Are you sure you want to delete "
    if (type is'tags') or (rest[0] is 'title')
      message += "this #{model.pretty_collection(type)}?"
    else
      message += "the #{rest[0]} of this #{model.pretty_collection(type)}?"
    share.confirmationDialog
      ok_button: 'Yes, delete it'
      no_button: 'No, cancel'
      message: message
      ok: ->
        processBlackboardEdit[type]?(null, id, rest...) # process delete
  "click .bb-canEdit .bb-editable": (event, template) ->
    # note that we rely on 'blur' on old field (which triggers ok or cancel)
    # happening before 'click' on new field
    Session.set 'editing', share.find_bbedit(event).join('/')
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
  tags_name: (text, id, canon) ->
    who = Session.get('nick')
    n = model.Names.findOne(id)
    if text is null # delete tag
      return Meteor.call 'deleteTag', {type:n.type, object:id, name:canon, who:who}
    tags = model.collection(n.type).findOne(id).tags
    t = (tag for tag in tags when tag.canon is canon)[0]
    Meteor.call 'setTag', {type:n.type, object:id, name:text, value:t.value, who:who}, (error,result) ->
      if (t.canon isnt model.canonical(text)) and (not error)
        Meteor.call 'deleteTag', {type:n.type, object:id, name:t.name, who:who}
  tags_value: (text, id, canon) ->
    n = model.Names.findOne(id)
    tags = model.collection(n.type).findOne(id).tags
    t = (tag for tag in tags when tag.canon is canon)[0]
    # special case for 'status' tag, which might not previously exist
    for special in ['Status', 'Answer']
      if (not t) and canon is model.canonical(special)
        t =
          name: special
          canon: model.canonical(special)
          value: ''
    # set tag (overwriting previous value)
    Meteor.call 'setTag', {type:n.type, object:id, name:t.name, value:text, who:Session.get('nick')}
  link: (text, id) ->
    n = model.Names.findOne(id)
    Meteor.call 'setField',
      type: n.type
      object: id
      who: Session.get 'nick'
      fields: link: text

Template.blackboard_round.helpers
  hasPuzzles: -> (this.round?.puzzles?.length > 0)
  showRound: ->
    return false if (Session.get 'hideRoundsSolvedMeta') and (this.round?.solved?)
    return (!Session.get 'hideSolved') or (!this.round?.solved?) or
    ((model.Puzzles.findOne(id) for id, index in this.round?.puzzles ? []).
      filter (p) -> !p?.solved?).length > 0
  showMeta: -> (!Session.get 'hideSolved') or (!this.round?.solved?)
  # the following is a map() instead of a direct find() to preserve order
  puzzles: ->
    p = ({
      round_num: this.round_num
      puzzle_num: 1 + index
      puzzle: model.Puzzles.findOne(id) or { _id: id }
      rXpY: "r#{this.round_num}p#{1+index}"
    } for id, index in this.round.puzzles)
    editing = (Session.get 'nick') and (Session.get 'canEdit')
    hideSolved = Session.get 'hideSolved'
    return p if editing or !hideSolved
    p.filter (pp) ->  !pp.puzzle.solved?
  tag: (name) ->
    return (model.getTag this.round, name) or ''
  whos_working: ->
    return model.Presence.find
      room_name: ("rounds/"+this.round?._id)
    , sort: ["nick"]
  local_working: ->
    count = 0
    model.Presence.find(room_name: ("rounds/"+this.round?._id)).forEach (p) ->
      count++ if share.isNickNear(p.nick)
    count
  compactMode: compactMode

Template.blackboard_puzzle.helpers
  tag: (name) ->
    return (model.getTag this.puzzle, name) or ''
  whos_working: ->
    return model.Presence.find
      room_name: ("puzzles/"+this.puzzle?._id)
    , sort: ["nick"]
  local_working: ->
    count = 0
    model.Presence.find(room_name: ("puzzles/"+this.puzzle?._id)).forEach (p) ->
      count++ if share.isNickNear(p.nick)
    count
  compactMode: compactMode

tagHelper = (id) ->
  isRoundGroup = ('rounds' of this)
  { id: id, name: t.name, canon: t.canon, value: t.value } \
    for t in (this?.tags or []) when not \
        ((Session.equals('currentPage', 'blackboard') and \
         (t.canon is 'status' or (!isRoundGroup and t.canon is 'answer'))) or \
         ((t.canon is 'answer' or t.canon is 'backsolve') and \
          (Session.equals('currentPage', 'puzzle') or \
           Session.equals('currentPage', 'round'))))

Template.blackboard_tags.helpers { tags: tagHelper }
Template.blackboard_puzzle_tags.helpers { tags: tagHelper }

# Subscribe to all group, round, and puzzle information
Template.blackboard.onCreated -> this.autorun =>
  this.subscribe 'all-presence'
  return if settings.BB_SUB_ALL
  this.subscribe 'all-roundsandpuzzles'

# Update 'currentTime' every minute or so to allow pretty_ts to magically
# update
Meteor.startup ->
  Meteor.setInterval ->
    Session.set "currentTime", model.UTCNow()
  , 60*1000

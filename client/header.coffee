# templates, event handlers, and subscriptions for the site-wide
# header bar, including the login modals and general Handlebars helpers

# link various types of objects
Handlebars.registerHelper 'link', (args) ->
  args = if typeof(args) is 'string' then {id:args} else args.hash
  n = Names.findOne(args.id)
  return args.id.slice(0,8) unless n
  return n.name if args.editing
  extraclasses = if args.class then (' '+args.class) else ''
  title = if args.title then " title='#{args.title}'" else ''
  link = "<a href='/#{n.type}/#{n._id}' class='#{n.type}-link#{extraclasses}' #{title}>"
  link += Handlebars._escape(n.name)
  link += '</a>'
  return new Handlebars.SafeString(link)

$('a.puzzles-link, a.rounds-link, a.chat-link, a.home-link').live 'click', (event) ->
  return unless event.button is 0 # check right-click
  event.preventDefault()
  Router.navigate $(this).attr('href'), {trigger:true}

# gravatars
Handlebars.registerHelper 'gravatar', (args) ->
  args = if typeof(args) is 'string' then {id:args} else args.hash
  g = $.gravatar(args.id, args)
  # hacky cross-platform version of 'outerHTML'
  html = $('<div>').append( g.eq(0).clone() ).html();
  return new Handlebars.SafeString(html)

############## log in/protect/mute panel ####################
Template.header_loginmute.volumeIcon = ->
  if Session.get "mute"
    "icon-volume-off"
  else
    "icon-volume-up"
Template.header_loginmute.sessionNick = ->
  nick = Session.get 'nick'
  return nick unless nick
  n = Nicks.findOne canon: canonical(nick)
  return {
    name: n?.name or nick
    canon: n?.canon or canonical(nick)
    realname: getTag n, 'Real Name'
    gravatar: (getTag n, 'Gravatar') or "#{nick}@#{DEFAULT_HOST}"
  }
Template.header_loginmute.rendered = ->
  # tool tips
  $(this.findAll('.bb-buttonbar *[title]')).tooltip placement: 'bottom'
# preserve buttons with tooltips, so they don't leak
Template.header_loginmute.preserve
  '.bb-buttonbar *[title]': (node) -> node.title
Template.header_loginmute.events
  "click .bb-login": (event, template) ->
    event.preventDefault()
    ensureNick()
  "click .bb-logout": (event, template) ->
    event.preventDefault()
    cleanupChat() if Session.equals('currentPage', 'chat')
    Session.set 'nick', undefined
    $.removeCookie 'nick', {path:'/'}
    if Session.equals('currentPage', 'chat')
      ensureNick -> # login again immediately
        joinRoom Session.get('type'), Session.get('id')
  "click .bb-protect, click .bb-unprotect": (event, template) ->
    canEdit = $(event.currentTarget).attr('data-canEdit') is 'true'
    Session.set 'canEdit', canEdit or undefined
    Session.set 'editing', undefined # abort current edit, whatever it is

############## nick selection ####################
Template.header_nickmodal.nickModalVisible = -> Session.get 'nickModalVisible'
Template.header_nickmodal.preserve ['#nickPickModal']
Template.header_nickmodal_contents.nick = -> Session.get "nick" or ''
Template.header_nickmodal_contents.created = ->
  this.sub = Meteor.subscribe 'all-nicks'
  this.afterFirstRender = =>
    $('#nickPickModal').one 'hide', ->
      Session.set 'nickModalVisible', undefined
    $('#nickPickModal').modal keyboard: false, backdrop:"static"
    $('#nickInput').select()
    firstNick = Session.get 'nick' or ''
    $('#nickInput').val firstNick
    this.update firstNick, force:true
    $('#nickInput').typeahead
      source: this.typeaheadSource
      updater: (item) =>
        this.update(item)
        return item
  this.typeaheadSource = (query,process) =>
    this.update(query)
    (n.name for n in Nicks.find({}).fetch())
  this.update = (query, options) =>
    # can we find an existing nick matching this?
    n = if query then Nicks.findOne canon: canonical(query) else undefined
    if (n or options?.force)
      realname = getTag n, 'Real Name'
      gravatar = getTag n, 'Gravatar'
      $('#nickRealname').val(realname or '')
      $('#nickEmail').val(gravatar or '')
    this.updateGravatar()
  this.updateGravatar = () =>
    email = $('#nickEmail').val() or ($('#nickInput').val()+'@'+DEFAULT_HOST)
    gravatar = $.gravatar email,
      image: 'wavatar' # 'monsterid'
      classes: 'img-polaroid'
    container = $(this.find('.gravatar'))
    if container.find('img').length
        container.find('img').attr('src', gravatar.attr('src'))
    else
        container.append(gravatar)
Template.header_nickmodal_contents.rendered = ->
  this.afterFirstRender?()
  this.afterFirstRender = undefined
Template.header_nickmodal_contents.destroyed = ->
  this.sub.stop()
Template.header_nickmodal_contents.events
  "click .bb-submit": (event, template) ->
    $('#nickPick').submit()
  "keydown #nickInput": (event, template) ->
    # implicit submit on <enter> if typeahead isn't shown
    if event.which is 13 and not $('#nickInput').data('typeahead').shown
      $('#nickPick').submit()
  "keydown #nickRealname": (event, template) ->
    $('#nickEmail').select() if event.which is 13
  "keydown #nickEmail": (event, template) ->
    $('#nickPick').submit() if event.which is 13
  "input #nickEmail": (event, template) ->
    template.updateGravatar()

$("#nickPick").live "submit", ->
  $warningGroup = $(this).find '#nickInputGroup'
  $warning = $(this).find "#nickInputGroup .help-inline"
  nick = $("#nickInput").val().replace(/^\s+|\s+$/g,"") #trim
  $warning.html ""
  $warningGroup.removeClass('error')
  if not nick || nick.length > 20
    $warning.html("Nickname must be between 1 and 20 characters long!");
    $warningGroup.addClass('error')
  else
    $.cookie "nick", nick, {expires: 365, path: '/'}
    Session.set "nick", nick
    realname = $('#nickRealname').val()
    gravatar = $('#nickEmail').val()
    Meteor.call 'newNick', {name: nick}, (error,n) ->
      tagsetter = (value, tagname, cb=(->)) ->
        value = value.replace(/^\s+|\s+$/g,"") # strip
        if getTag(n, tagname) is value
          cb()
        else
          Meteor.call 'setTag', 'nicks', n._id, tagname, value, n.canon, ->
            cb()
      tagsetter realname, 'Real Name', ->
        tagsetter gravatar, 'Gravatar'
    $('#nickPickModal').modal 'hide'

  hideMessageAlert()
  return false

changeNick = (cb=(->)) ->
  $('#nickPickModal').one 'hide', -> cb()
  Session.set 'nickModalVisible', true

ensureNick = (cb=(->)) ->
  if Session.get 'nick'
    cb()
  else if $.cookie('nick')
    Session.set 'nick', $.cookie('nick')
    cb()
  else
    changeNick cb


############## operation log in header ####################
Template.header_lastupdates.lastupdates = ->
  LIMIT = 10
  ologs = OpLogs.find {}, \
        {sort: [["timestamp","desc"]], limit_BUG: LIMIT}
  # Meteor doesn't support the limit option yet.  So in a hacky workaround,
  # limit the collection client-side
  ologs = ologs.fetch().slice(0, LIMIT)
  # now look through the entries and collect similar logs
  # this way we can say "New puzzles: X, Y, and Z" instead of just "New Puzzle: Z"
  return '' unless ologs && ologs.length
  message = [ ologs[0] ]
  for ol in ologs[1..]
    if ol.message is message[0].message and ol.type is message[0].type
      message.push ol
    else
      break
  type = ''
  if message[0].id
    type = ' ' + pretty_collection(message[0].type) + \
      (if message.length > 1 then 's ' else ' ')
  return {
    timestamp: message[0].timestamp
    message: message[0].message + type
    nick: message[0].nick
    objects: ({type:m.type,id:m.id} for m in message)
  }

# subscribe when this template is in use/unsubscribe when it is destroyed
Template.header_lastupdates.created = ->
  this.sub = Meteor.subscribe 'recent-oplogs'
Template.header_lastupdates.destroyed = ->
  this.sub.stop()

############## chat log in header ####################
Template.header_lastchats.lastchats = ->
  LIMIT = 2
  m = Messages.find {room_name: "general/0", system: false}, \
        {sort: [["timestamp","desc"]], limit_BUG: LIMIT}
  # Meteor doesn't support the limit option yet.  So in a hacky workaround,
  # limit the collection client-side
  m = m.fetch().slice(0, LIMIT)
  m.reverse()
  return m
Template.header_lastchats.pretty_ts = (ts) -> Template.messages.pretty_ts ts

# subscribe when this template is in use/unsubscribe when it is destroyed
Template.header_lastchats.created = ->
  this.sub = Meteor.subscribe 'recent-messages', 'general/0'
Template.header_lastchats.destroyed = ->
  this.sub.stop()

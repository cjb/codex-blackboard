# templates, event handlers, and subscriptions for the site-wide
# header bar, including the login modals and general Handlebars helpers

keyword_or_positional = (name, args) ->
  return args.hash unless (not args?) or \
    (typeof(args) is 'string') or (typeof(args) is 'number')
  a = {}
  a[name] = args
  return a

# link various types of objects
Handlebars.registerHelper 'link', (args) ->
  args = keyword_or_positional 'id', args
  n = Names.findOne(args.id)
  return args.id.slice(0,8) unless n
  return n.name if args.editing
  extraclasses = if args.class then (' '+args.class) else ''
  title = if args.title then " title='#{args.title}'" else ''
  link = "<a href='/#{n.type}/#{n._id}' class='#{n.type}-link#{extraclasses}' #{title}>"
  link += Handlebars._escape(n.name)
  link += '</a>'
  return new Handlebars.SafeString(link)

$('a.puzzles-link, a.rounds-link, a.chat-link, a.home-link, a.oplogs-link').live 'click', (event) ->
  return unless event.button is 0 # check right-click
  return if event.ctrlKey or event.shiftKey # check ctrl/shift clicks
  event.preventDefault()
  Router.navigate $(this).attr('href'), {trigger:true}

Handlebars.registerHelper 'drive_link', (args) ->
  args = keyword_or_positional 'id', args
  return drive_id_to_link(args.id)

# nicks
Handlebars.registerHelper 'nickOrName', (args) ->
  nick = (keyword_or_positional 'nick', args).nick
  n = Nicks.findOne canon: canonical(nick)
  return getTag(n, 'Real Name') or nick

# gravatars
Handlebars.registerHelper 'gravatar', (args) ->
  args = keyword_or_positional 'id', args
  g = $.gravatar(args.id, args)
  # hacky cross-platform version of 'outerHTML'
  html = $('<div>').append( g.eq(0).clone() ).html();
  return new Handlebars.SafeString(html)

# timestamps
Handlebars.registerHelper 'pretty_ts', (args) ->
  timestamp = (keyword_or_positional 'timestamp', args).timestamp
  return unless timestamp
  d = new Date(timestamp)
  hrs = d.getHours()
  ampm = if hrs < 12 then 'AM' else 'PM'
  hrs = 12 if hrs is 0
  hrs = (hrs-12) if hrs > 12
  min = d.getMinutes()
  min = if min < 10 then "0" + min else min
  hrs + ":" + min + ' ' + ampm

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
  '.bb-buttonbar *[data-original-title]': (node) ->
     $(node).attr('data-original-title')
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

############## breadcrumbs #######################
Template.header_breadcrumbs.round = ->
  if Session.equals('type', 'puzzles')
    Rounds.findOne puzzles: Session.get("id")
  else if Session.equals('type', 'rounds')
    Rounds.findOne Session.get('id')
  else null
Template.header_breadcrumbs.puzzle = ->
  if Session.equals('type', 'puzzles')
    Puzzles.findOne Session.get('id')
  else null
Template.header_breadcrumbs.type = -> Session.get('type')
Template.header_breadcrumbs.id = -> Session.get('id')
Template.header_breadcrumbs.drive = -> switch Session.get('type')
  when 'general'
    RINGHUNTERS_FOLDER
  when 'rounds', 'puzzles'
    collection(Session.get('type'))?.findOne(Session.get('id'))?.drive
Template.header_breadcrumbs.events
  "click .bb-upload-file": (event, template) ->
     folder = switch Session.get('type')
       when 'general'
         RINGHUNTERS_FOLDER
       when 'rounds', 'puzzles'
         collection(Session.get('type'))?.findOne(Session.get('id'))?.drive
     return unless folder
     uploadToDriveFolder folder, (docs) ->
        message = "uploaded "+(for doc in docs
          "<a href='#{doc.url}' target='_blank'><img src='#{doc.iconUrl}' />#{doc.name}</a> "
        ).join(', ')
        Meteor.call 'newMessage',
          body: message
          bodyIsHtml: true
          nick: Session.get 'nick'
          action: true
          room_name: Session.get('type')+'/'+Session.get('id')
Template.header_breadcrumbs.rendered = ->
  # tool tips
  $(this.findAll('a.bb-drive-link[title]')).tooltip placement: 'bottom'
# preserve buttons with tooltips, so they don't leak
Template.header_breadcrumbs.preserve
  'a.bb-drive-link[title]': (node) -> node.title
  'a.bb-drive-link[data-original-title]': (node) ->
     $(node).attr('data-original-title')

uploadToDriveFolder = (folder, callback) ->
  uploadView = new google.picker.DocsUploadView()\
    .setParent(folder)
  pickerCallback = (data) ->
    switch data[google.picker.Response.ACTION]
      when "loaded"
        return
      when google.picker.Action.PICKED
        doc = data[google.picker.Response.DOCUMENTS][0]
        url = doc[google.picker.Document.URL]
        callback data[google.picker.Response.DOCUMENTS]
      else
        console.log 'Unexpected action:', data
  new google.picker.PickerBuilder()\
    .setAppId('365816747654.apps.googleusercontent.com')\
    .setTitle('Upload Item')\
    .addView(uploadView)\
    .enableFeature(google.picker.Feature.NAV_HIDDEN)\
    .enableFeature(google.picker.Feature.MULTISELECT_ENABLED)\
    .setCallback(pickerCallback)\
    .build().setVisible true


############## nick selection ####################
Template.header_nickmodal.nickModalVisible = -> Session.get 'nickModalVisible'
Template.header_nickmodal.preserve ['#nickPickModal']
Template.header_nickmodal_contents.nick = -> Session.get "nick" or ''
Template.header_nickmodal_contents.created = ->
  # we'd need to subscribe to 'all-nicks' here if we didn't have a permanent
  # subscription to it (in main.coffee)
  this.afterFirstRender = =>
    $('#nickPickModal').one 'hide', ->
      Session.set 'nickModalVisible', undefined
    $('#nickSuccess').val('false')
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
    $('#nickSuccess').val('true')
    $('#nickPickModal').modal 'hide'

  hideMessageAlert()
  return false

changeNick = (cb) ->
  $('#nickPickModal').one 'hide', ->
    cb?() if $('#nickSuccess').val() is 'true'
  Session.set 'nickModalVisible', true

ensureNick = (cb=(->)) ->
  if Session.get 'nick'
    cb()
  else if $.cookie('nick')
    Session.set 'nick', $.cookie('nick')
    cb()
  else
    changeNick cb

############## confirmation dialog ########################
Template.header_confirmmodal.confirmModalVisible = ->
  !!(Session.get 'confirmModalVisible')
Template.header_confirmmodal.preserve ['#confirmModal']
Template.header_confirmmodal_contents.created = ->
  this.afterFirstRender = =>
    $('#confirmModal').modal show: true
Template.header_confirmmodal_contents.rendered = ->
  this.afterFirstRender?()
  this.afterFirstRender = undefined
Template.header_confirmmodal_contents.events
  "click .bb-confirm-ok": (event, template) ->
     Template.header_confirmmodal_contents.cancel = false # do the thing!
     $('#confirmModal').modal 'hide'

confirmationDialog = (options) ->
  $('#confirmModal').one 'hide', ->
    Session.set 'confirmModalVisible', undefined
    options.ok?() unless Template.header_confirmmodal_contents.cancel
  # store away options before making dialog visible
  Template.header_confirmmodal_contents.options = -> options
  Template.header_confirmmodal_contents.cancel = true
  Session.set 'confirmModalVisible', (options or Object.create(null))

############## operation log in header ####################
Template.header_lastupdates.lastupdates = ->
  LIMIT = 10
  ologs = OpLogs.find {}, \
        {sort: [["timestamp","desc"]], limit: LIMIT}
  ologs = ologs.fetch()
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
  uniq = (array) ->
    seen = Object.create(null)
    ((seen[o.id]=o) for o in array when not (o.id of seen))
  return {
    timestamp: message[0].timestamp
    message: message[0].message + type
    nick: message[0].nick
    objects: uniq({type:m.type,id:m.id} for m in message)
  }

# subscribe when this template is in use/unsubscribe when it is destroyed
Template.header_lastupdates.created = ->
  this.sub = Meteor.subscribe 'recent-oplogs'
Template.header_lastupdates.destroyed = ->
  this.sub.stop()
# add tooltip to 'more' links, and preserve then so they doesn't leak
do ->
  for t in ['header_lastupdates', 'header_lastchats']
    Template[t].rendered = ->
      $(this.findAll('.right a[title]')).tooltip placement: 'left'
    Template[t].preserve
      '.right a[title]': (node) -> node.title
      '.right a[data-original-title]': (node) ->
        $(node).attr('data-original-title')

############## chat log in header ####################
Template.header_lastchats.lastchats = ->
  LIMIT = 2
  m = Messages.find {room_name: "general/0", system: false}, \
        {sort: [["timestamp","desc"]], limit: LIMIT}
  m = m.fetch().reverse()
  return m
Template.header_lastchats.body = ->
  if this.bodyIsHtml then new Handlebars.SafeString(this.body) else this.body

# subscribe when this template is in use/unsubscribe when it is destroyed
Template.header_lastchats.created = ->
  this.run = Meteor.autorun =>
    # use autorun to ensure subscription changes if/when nick does
    nick = Session.get('nick')
    this.sub?.stop?()
    this.sub = Meteor.subscribe 'recent-messages', nick, 'general/0'
Template.header_lastchats.destroyed = ->
  this.sub.stop()
  this.run.stop()

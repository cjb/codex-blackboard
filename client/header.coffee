'use strict'
model = share.model # import
settings = share.settings # import

# templates, event handlers, and subscriptions for the site-wide
# header bar, including the login modals and general Spacebars helpers

Meteor.startup ->
  Meteor.call 'getRinghuntersFolder', (error, f) ->
    unless error?
      Session.set 'RINGHUNTERS_FOLDER', (f or undefined)

keyword_or_positional = share.keyword_or_positional = (name, args) ->
  return args.hash unless (not args?) or \
    (typeof(args) is 'string') or (typeof(args) is 'number')
  a = {}
  a[name] = args
  return a

# link various types of objects
Template.registerHelper 'link', (args) ->
  args = keyword_or_positional 'id', args
  return "" unless args.id
  n = model.Names.findOne(args.id)
  return args.id.slice(0,8) unless n
  return ('' + (args.text ? n.name)) if args.editing
  extraclasses = if args.class then (' '+args.class) else ''
  title = ''
  if args.title?
    title = ' title="' + \
      args.title.replace(/[&\"]/g, (c) -> '&#' + c.charCodeAt(0) + ';') + '"'
  prefix = if args.chat then '/chat' else ''
  type = if args.chat then 'chat' else n.type
  link = "<a href='#{prefix}/#{n.type}/#{n._id}' class='#{type}-link#{extraclasses}' #{title}>"
  if args.icon
    link += "<i class='#{args.icon}'></i>"
  else
    link += UI._escape('' + (args.text ? n.name))
  link += '</a>'
  return new Spacebars.SafeString(link)

$(document).on 'click', 'a.puzzles-link, a.rounds-link, a.chat-link, a.home-link, a.oplogs-link, a.quips-link', (event) ->
  return unless event.button is 0 # check right-click
  return if event.ctrlKey or event.shiftKey or event.altKey # check alt/ctrl/shift clicks
  return if /^https?:/.test($(event.currentTarget).attr('href'))
  event.preventDefault()
  if $(this).hasClass('bb-pop-out')
    window.open $(event.currentTarget).attr('href'), 'Pop out', \
      ("height=480,width=480,menubar=no,toolbar=no,personalbar=no,"+\
       "status=yes,resizeable=yes,scrollbars=yes")
  else
    share.Router.navigate $(this).attr('href'), {trigger:true}

Template.registerHelper 'drive_link', (args) ->
  args = keyword_or_positional 'id', args
  return model.drive_id_to_link(args.id)
Template.registerHelper 'spread_link', (args) ->
  args = keyword_or_positional 'id', args
  return model.spread_id_to_link(args.id)

# nicks
Template.registerHelper 'nickOrName', (args) ->
  nick = (keyword_or_positional 'nick', args).nick
  n = model.Nicks.findOne canon: model.canonical(nick)
  return model.getTag(n, 'Real Name') or nick

Template.registerHelper 'lotsOfPeople', (args) ->
  count = (keyword_or_positional 'count', args).count
  return count > 4

# gravatars
Template.registerHelper 'gravatar', (args) ->
  args = keyword_or_positional 'id', args
  args.secure = true
  g = $.gravatar(args.id, args)
  # hacky cross-platform version of 'outerHTML'
  html = $('<div>').append( g.eq(0).clone() ).html()
  return new Spacebars.SafeString(html)

# timestamps
Template.registerHelper 'pretty_ts', (args) ->
  args = keyword_or_positional 'timestamp', args
  timestamp = args.timestamp
  return unless timestamp
  style = (args.style or "time")
  switch (style)
    when "time"
      d = new Date(timestamp)
      hrs = d.getHours()
      ampm = if hrs < 12 then 'AM' else 'PM'
      hrs = 12 if hrs is 0
      hrs = (hrs-12) if hrs > 12
      min = d.getMinutes()
      min = if min < 10 then "0" + min else min
      hrs + ":" + min + ' ' + ampm
    when "duration", "brief_duration", "brief duration"
      brief = (style isnt 'duration')
      duration = (Session.get('currentTime') or model.UTCNow()) - timestamp
      seconds = Math.floor(duration/1000)
      return "in the future" if seconds < -60
      return "just now" if seconds < 60
      [minutes, seconds] = [Math.floor(seconds/60), seconds % 60]
      [hours,   minutes] = [Math.floor(minutes/60), minutes % 60]
      [days,    hours  ] = [Math.floor(hours  /24), hours   % 24]
      [weeks,   days   ] = [Math.floor(days   / 7), days    % 7]
      ago = (s) -> (s.replace(/^\s+/,'') + " ago")
      s = ""
      s += " #{weeks} week" if weeks > 0
      s += "s" if weeks > 1
      return ago(s) if s and brief
      s += " #{days} day" if days > 0
      s += "s" if days > 1
      return ago(s) if s and brief
      s += " #{hours} hour" if hours > 0
      s += "s" if hours > 1
      return ago(s) if s and brief
      s += " #{minutes} minute" if minutes > 0
      s += "s" if minutes > 1
      return ago(s)
    else
      "Unknown timestamp style: #{style}"

# Scroll spy
Template.registerHelper 'updateScrollSpy', (args) ->
  ss = $("body").data("scrollspy")
  ss?.refresh()
  return ''

############## log in/protect/mute panel ####################
Template.header_loginmute.helpers
  volumeIcon: ->
    if Session.get "mute" then "icon-volume-off" else "icon-volume-up"
  volumeTitle: ->
    if Session.get "mute" then "Muted" else "Click to mute"
  botIcon: ->
    if Session.get "nobot" then "icon-bot-off" else "icon-bot-on"
  botTitle: ->
    if Session.get "nobot"
      "Codexbot promises not to bother you"
    else
      "Codexbot is feeling chatty!"
  sessionNick: ->
    nick = Session.get 'nick'
    return nick unless nick
    n = model.Nicks.findOne canon: model.canonical(nick)
    cn = n?.canon or model.canonical(nick)
    return {
      name: n?.name or nick
      canon: cn
      realname: model.getTag n, 'Real Name'
      gravatar: (model.getTag n, 'Gravatar') or "#{cn}@#{settings.DEFAULT_HOST}"
    }
  wikipage: ->
    return '' if Session.equals('currentPage', 'blackboard')
    [type, id] = [Session.get('type'), Session.get('id')]
    return '' unless (type and id)
    switch type
      when 'puzzles'
        round = model.Rounds.findOne puzzles: id
        group = model.RoundGroups.findOne rounds: round?._id
        puzzle_num = 1 + (round?.puzzles or []).indexOf(id)
        round_num = 1 + group?.round_start + \
          (group?.rounds or []).indexOf(round?._id)
        "#{settings.HUNT_YEAR}/R#{round_num}P#{puzzle_num}"
      when 'rounds'
        group = model.RoundGroups.findOne rounds: id
        round_num = 1 + group?.round_start + \
          (group?.rounds or []).indexOf(id)
        "#{settings.HUNT_YEAR}/R#{round_num}P0"
      else
        ''

Template.header_loginmute.onRendered ->
  # tool tips
  $(this.findAll('.bb-buttonbar *[title]')).tooltip
    placement: 'bottom'
    container: '.bb-buttonbar'

Template.header_loginmute.events
  "click .bb-login": (event, template) ->
    event.preventDefault()
    ensureNick()
  "click .bb-logout": (event, template) ->
    event.preventDefault()
    share.chat.cleanupChat() if Session.equals('currentPage', 'chat')
    $.removeCookie 'nick', {path:'/'}
    Session.set
      nick: undefined
      canEdit: undefined
      editing: undefined
    if Session.equals('currentPage', 'chat')
      ensureNick -> # login again immediately
        share.chat.joinRoom Session.get('type'), Session.get('id')
  "click .bb-protect, click .bb-unprotect": (event, template) ->
    target = event.currentTarget
    ensureNick ->
      canEdit = $(target).attr('data-canEdit') is 'true'
      Session.set
        canEdit: (canEdit or undefined)
        editing: undefined # abort current edit, whatever it is

############## breadcrumbs #######################
Template.header_breadcrumbs.helpers
  round: ->
    if Session.equals('type', 'puzzles')
      model.Rounds.findOne puzzles: Session.get("id")
    else if Session.equals('type', 'rounds')
      model.Rounds.findOne Session.get('id')
    else null
  puzzle: ->
    if Session.equals('type', 'puzzles')
      model.Puzzles.findOne Session.get('id')
    else null
  quip: ->
    if Session.equals('type', 'quips')
      model.Quips.findOne Session.get('id')
    else null
  type: -> Session.get('type')
  id: -> Session.get('id')
  idIsNew: -> Session.equals('id', 'new')
  drive: -> switch Session.get('type')
    when 'general'
      Session.get 'RINGHUNTERS_FOLDER'
    when 'rounds', 'puzzles'
      model.collection(Session.get('type'))?.findOne(Session.get('id'))?.drive

Template.header_breadcrumbs.events
  "mouseup .fake-link[data-href]": (event, template) ->
    # we work hard to try to make middle-click, shift-click, etc still work.
    a = $(event.currentTarget).closest('a')
    href = $(event.currentTarget).attr('data-href')
    oldhref = a.attr('href')
    a.attr('href', href)
    Meteor.setTimeout (-> a.attr('href', oldhref)), 100
  "click .bb-upload-file": (event, template) ->
    folder = switch Session.get('type')
      when 'general'
        Session.get 'RINGHUNTERS_FOLDER'
      when 'rounds', 'puzzles'
        model.collection(Session.get('type'))?.findOne(Session.get('id'))?.drive
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

Template.header_breadcrumbs.onRendered ->
  # tool tips
  $(this.findAll('a.bb-drive-link[title]')).tooltip placement: 'bottom'

uploadToDriveFolder = share.uploadToDriveFolder = (folder, callback) ->
  google = window?.google
  gapi = window?.gapi
  unless google? and gapi?
    console.warn 'Google APIs not loaded; Google Drive disabled.'
    return
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
  gapi.auth.authorize
    client_id: '571639156428-60p46e0himfh5flqducjd4komitga1d4.apps.googleusercontent.com'
    scope: ['https://www.googleapis.com/auth/drive']
    immediate: false
  , (authResult) ->
    oauthToken = authResult?.access_token
    if authResult?.error or !oauthToken
      console.log 'Authentication failed', authResult
      return
    new google.picker.PickerBuilder()\
      .setAppId('365816747654.apps.googleusercontent.com')\
      .setDeveloperKey('AIzaSyC5h171Bt3FrLlSYDur-RbvTXwgxXYgUv0')\
      .setOAuthToken(oauthToken)\
      .setTitle('Upload Item')\
      .addView(uploadView)\
      .enableFeature(google.picker.Feature.NAV_HIDDEN)\
      .enableFeature(google.picker.Feature.MULTISELECT_ENABLED)\
      .setCallback(pickerCallback)\
      .build().setVisible true


############## nick selection ####################
Template.header_nickmodal.helpers
  nickModalVisible: -> Session.get 'nickModalVisible'

Template.header_nickmodal_contents.helpers
  nick: -> Session.get "nick" or ''
Template.header_nickmodal_contents.onCreated ->
  # we'd need to subscribe to 'all-nicks' here if we didn't have a permanent
  # subscription to it (in main.coffee)
  this.typeaheadSource = (query,process) =>
    this.update(query)
    (n.name for n in model.Nicks.find({}).fetch())
  this.update = (query, options) =>
    # can we find an existing nick matching this?
    n = if query \
        then model.Nicks.findOne canon: model.canonical(query) \
        else undefined
    if (n or options?.force)
      realname = model.getTag n, 'Real Name'
      gravatar = model.getTag n, 'Gravatar'
      $('#nickRealname').val(realname or '')
      $('#nickEmail').val(gravatar or '')
    this.updateGravatar()
  this.updateGravatar = () =>
    email = $('#nickEmail').val() or "#{model.canonical($('#nickInput').val())}@#{settings.DEFAULT_HOST}"
    gravatar = $.gravatar email,
      image: 'wavatar' # 'monsterid'
      classes: 'img-polaroid'
      secure: true
    container = $(this.find('.gravatar'))
    if container.find('img').length
      container.find('img').attr('src', gravatar.attr('src'))
    else
      container.append(gravatar)
Template.header_nickmodal_contents.onRendered ->
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

$(document).on 'submit', '#nickPick', ->
  $warningGroup = $(this).find '#nickInputGroup'
  $warning = $(this).find "#nickInputGroup .help-inline"
  nick = $("#nickInput").val().replace(/^\s+|\s+$/g,"") #trim
  $warning.html ""
  $warningGroup.removeClass('error')
  if not nick || nick.length > 20
    $warning.html("Nickname must be between 1 and 20 characters long!")
    $warningGroup.addClass('error')
  else
    $.cookie "nick", nick, {expires: 365, path: '/'}
    Session.set "nick", nick
    realname = $('#nickRealname').val()
    gravatar = $('#nickEmail').val()
    Meteor.call 'newNick', {name: nick}, (error,n) ->
      tagsetter = (value, tagname, cb=(->)) ->
        value = value.replace(/^\s+|\s+$/g,"") # strip
        if model.getTag(n, tagname) is value
          cb()
        else
          Meteor.call 'setTag', {type:'nicks', object:n._id, name:tagname, value:value, who:n.canon}, ->
            cb()
      tagsetter realname, 'Real Name', ->
        tagsetter gravatar, 'Gravatar'
    $('#nickSuccess').val('true')
    $('#nickPickModal').modal 'hide'

  share.chat.hideMessageAlert()
  return false

changeNick = (cb) ->
  $('#nickPickModal').one 'hide', ->
    cb?() if $('#nickSuccess').val() is 'true'
  Session.set 'nickModalVisible', true

ensureNick = share.ensureNick = (cb=(->)) ->
  if Session.get 'nick'
    cb()
  else if $.cookie('nick')
    Session.set 'nick', $.cookie('nick')
    cb()
  else
    changeNick cb

############## confirmation dialog ########################
Template.header_confirmmodal.helpers
  confirmModalVisible: -> !!(Session.get 'confirmModalVisible')
Template.header_confirmmodal_contents.onRendered ->
  $('#confirmModal').modal show: true
Template.header_confirmmodal_contents.events
  "click .bb-confirm-ok": (event, template) ->
    Template.header_confirmmodal_contents.cancel = false # do the thing!
    $('#confirmModal').modal 'hide'

confirmationDialog = share.confirmationDialog = (options) ->
  $('#confirmModal').one 'hide', ->
    Session.set 'confirmModalVisible', undefined
    options.ok?() unless Template.header_confirmmodal_contents.cancel
  # store away options before making dialog visible
  Template.header_confirmmodal_contents.options = -> options
  Template.header_confirmmodal_contents.cancel = true
  Session.set 'confirmModalVisible', (options or Object.create(null))

############## operation log in header ####################
Template.header_lastupdates.helpers
  lastupdates: ->
    LIMIT = 10
    ologs = model.Messages.find {room_name: "oplog/0"}, \
          {sort: [["timestamp","desc"]], limit: LIMIT}
    ologs = ologs.fetch()
    # now look through the entries and collect similar logs
    # this way we can say "New puzzles: X, Y, and Z" instead of just
    # "New Puzzle: Z"
    return '' unless ologs && ologs.length
    message = [ ologs[0] ]
    for ol in ologs[1..]
      if ol.body is message[0].body and ol.type is message[0].type
        message.push ol
      else
        break
    type = ''
    if message[0].id
      type = ' ' + model.pretty_collection(message[0].type) + \
        (if message.length > 1 then 's ' else ' ')
    uniq = (array) ->
      seen = Object.create(null)
      ((seen[o.id]=o) for o in array when not (o.id of seen))
    return {
      timestamp: message[0].timestamp
      message: message[0].body + type
      nick: message[0].nick
      objects: uniq({type:m.type,id:m.id} for m in message)
    }

# subscribe when this template is in use/unsubscribe when it is destroyed
Template.header_lastupdates.onCreated ->
  this.autorun =>
    p = share.chat.pageForTimestamp 'oplog/0', 0, {subscribe:this}
    return unless p? # wait until page info is loaded
    messages = if p.archived then "oldmessages" else "messages"
    this.subscribe "#{messages}-in-range", p.room_name, p.from, p.to
# add tooltip to 'more' links
do ->
  for t in ['header_lastupdates', 'header_lastchats']
    Template[t].onRendered ->
      $(this.findAll('.right a[title]')).tooltip placement: 'left'

############## chat log in header ####################
Template.header_lastchats.helpers
  lastchats: ->
    LIMIT = 2
    m = model.Messages.find {
      room_name: "general/0", system: false, bodyIsHtml: false
    }, {sort: [["timestamp","desc"]], limit: LIMIT}
    m = m.fetch().reverse()
    return m
  msgbody: ->
    if this.bodyIsHtml then new Spacebars.SafeString(this.body) else this.body

# subscribe when this template is in use/unsubscribe when it is destroyed
Template.header_lastchats.onCreated ->
  return if settings.BB_DISABLE_RINGHUNTERS_HEADER
  this.autorun =>
    p = share.chat.pageForTimestamp 'general/0', 0, {subscribe:this}
    return unless p? # wait until page info is loaded
    messages = if p.archived then "oldmessages" else "messages"
    # use autorun to ensure subscription changes if/when nick does
    nick = (Session.get 'nick') or null
    if nick? and not settings.BB_DISABLE_PM
      this.subscribe "#{messages}-in-range-nick", nick, p.room_name, p.from, p.to
    this.subscribe "#{messages}-in-range", p.room_name, p.from, p.to

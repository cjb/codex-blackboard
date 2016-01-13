'use strict'
model = share.model
chat = share.chat

Template.oplog.helpers
  prevTimestamp: ->
    p = chat.pageForTimestamp 'oplog/0', +Session.get('timestamp')
    return unless p?.from
    "/oplogs/#{p.from}"
  oplogs: ->
    p = chat.pageForTimestamp 'oplog/0', +Session.get('timestamp')
    chat.messagesForPage p,
      sort: [['timestamp','asc']]
  prettyType: ->
    model.pretty_collection(this.type)
  nextTimestamp: ->
    p = chat.pageForTimestamp 'oplog/0', +Session.get('timestamp')
    return unless p?.next?
    p = model.Pages.findOne(p.next)
    return unless p?
    "/oplogs/#{p.to}"
  timestamp: ->
    +Session.get('timestamp')

Template.oplog.onRendered ->
  $("title").text("Operation Log Archive")
  $("body").scrollTo 'max'

Template.oplog.onCreated -> this.autorun =>
  room_name = 'oplog/0'
  timestamp = +Session.get('timestamp')
  p = chat.pageForTimestamp room_name, timestamp, {subscribe:this}
  return unless p? # wait until page info is loaded
  messages = if p.archived then "oldmessages" else "messages"
  this.subscribe "#{messages}-in-range", room_name, p.from, p.to
  # subscribe to the 'prev' and 'next' pages as well
  if p.next?
    this.subscribe 'page-by-id', p.next
  if p.prev?
    this.subscribe 'page-by-id', p.prev

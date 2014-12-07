'use strict'
model = share.model
chat = share.chat

Template.oplog.prevTimestamp = ->
  p = chat.pageForTimestamp 'oplog/0', +Session.get('timestamp')
  return unless p?.from
  "/oplogs/#{p.from}"
Template.oplog.oplogs = ->
  p = chat.pageForTimestamp 'oplog/0', +Session.get('timestamp')
  chat.messagesForPage p,
    sort: [['timestamp','asc']]
Template.oplog.nextTimestamp = ->
  p = chat.pageForTimestamp 'oplog/0', +Session.get('timestamp')
  return unless p?.next?
  p = model.Pages.findOne(p.next)
  return unless p?
  "/oplogs/#{p.to}"
Template.oplog.timestamp = -> +Session.get('timestamp')

Template.oplog.rendered = ->
  $("title").text("Operation Log Archive")
  $("body").scrollTo 'max'

Tracker.autorun ->
  return unless Session.equals("currentPage", "oplog")
  room_name = 'oplog/0'
  timestamp = +Session.get('timestamp')
  p = chat.pageForTimestamp room_name, timestamp, 'subscribe'
  return unless p? # wait until page info is loaded
  Meteor.subscribe 'messages-in-range', room_name, p.from, p.to
  # subscribe to the 'prev' and 'next' pages as well
  if p.next?
    Meteor.subscribe 'page-by-id', p.next
  if p.prev?
    Meteor.subscribe 'page-by-id', p.prev

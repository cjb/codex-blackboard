'use strict'
model = share.model

Template.oplog.oplogs = ->
  timestamp = (+Session.get('timestamp')) or Number.MAX_VALUE
  ops = model.Messages.find {room_name: 'oplog/0', timestamp: $lt: +timestamp},
    sort: [["timestamp","desc"]]
    limit: model.MESSAGE_PAGE
  for oplog, i in ops.fetch().reverse()
    first: (i is 0)
    oplog: oplog
Template.oplog.timestamp = -> +Session.get('timestamp')

Template.oplog.created = ->
  this.afterFirstRender = ->
    $("body").scrollTo 'max'
Template.oplog.rendered = ->
  $("title").text("Operation Log Archive")
  this.afterFirstRender?()
  this.afterFirstRender = undefined

Deps.autorun ->
  return unless Session.equals("currentPage", "oplog")
  timestamp = Session.get('timestamp')
  Meteor.subscribe 'paged-messages', 'oplog/0', ((+timestamp) or 0)

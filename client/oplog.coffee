Template.oplog.oplogs = ->
  timestamp = (+Session.get('timestamp')) or Number.MAX_VALUE
  ops = OpLogs.find {timestamp: $lt: +timestamp},
    sort: [["timestamp","desc"]]
    limit: OPLOG_PAGE
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

Meteor.autorun ->
  return unless Session.equals("currentPage", "oplog")
  timestamp = +Session.get('timestamp')
  Meteor.subscribe 'paged-oplogs', (+timestamp) or Number.MAX_VALUE

# Watch an email account and announce new mail to general/0 chat.

# The account to watch is given in settings.json, like so:
# {
#   "watch": {
#     "username": "xxxxx@gmail.com",
#     "password": "yyyyy",
#     "host": "imap.gmail.com",
#     "port": 993,
#     "secure": true
#   }
# }
# To find the proper values for an email address, try the imap-autoconfig
# package.

watch = Meteor.settings?.watch ? {}

return unless watch.username and watch.password
mailListener = new MailListener
  username: watch.username
  password: watch.password
  host: watch.host ? 'imap.gmail.com'
  port: watch.port ? 993
  tls: watch.tls ? true
  tlsOptions: watch.tlsOptions ? { rejectUnauthorized: false }
  mailbox: watch.mailbox ? 'INBOX'
  markSeen: watch.markSeen ? true
  fetchUnreadOnStart: false
  mailParserOptions: watch.mailParserOptions ? { streamAttachments: true }

mailListener.on 'server:connected', ->
  console.log 'Watching for mail to', watch.username
mailListener.on 'error', (err) ->
  console.error 'IMAP error', err

mailListener.on 'mail', (mail) ->
  # mail arrived! fields:
  #  text -- body plaintext
  #  html -- optional field, contains body formatted as HTML
  #  headers -- hash, with 'sender', 'date', 'subject', 'from', 'to' (unparsed)
  #  subject, messageId, priority
  #  from -- array of objects with 'address' and 'name' fields
  #  to -- same as from
  #  attachements -- an array of objects with various fields
  console.log 'Mail from HQ arrived:', mail.subject
  Meteor.call 'newMessage',
    nick: 'thehunt'
    action: true
    body: "sent mail: #{mail.subject}"
    bot_ignore: true
  Meteor.call 'newMessage',
    nick: 'thehunt'
    body: mail.html ? mail.text
    bodyIsHtml: mail.html?
    bot_ignore: true

Meteor.startup ->
  mailListener.start()

# Watch twitter and announce new tweets to general/0 chat.
#_
# The account login details are given in settings.json, like so:
# {
#   "twitter": {
#     "consumer_key": "xxxxxxxxx",
#     "consumer_secret": "yyyyyyyyyyyy",
#     "access_token_key": "zzzzzzzzzzzzzzzzzzzzzz",
#     "access_token_secret": "wwwwwwwwwwwwwwwwwwwwww"
#   }
# }
settings = Meteor.settings?.twitter ? {}

return unless settings.consumer_key and settings.consumer_secret
return unless settings.access_token_key and settings.access_token_secret
twit = new Twitter
  consumer_key: settings.consumer_key
  consumer_secret: settings.consumer_secret
  access_token_key: settings.access_token_key
  access_token_secret: settings.access_token_secret

linkify = do ->
  # linkify hashtags, URLs, and usernames.  Do this all in one pass so
  # that we don't try to linkify the contents of a previously-converted
  # link  (ie, when given `http://user@host/foo#bar` ).
  hashtagRE = /\#(?:\w+)/
  usernameRE = /@(?:[a-z0-9_]{1,15})(?![.a-z0-9_])/i
  # Note that we are using Gruber's "Liberal, Accurate Regex Pattern",
  # as amended by @cscott in https://gist.github.com/gruber/249502
  urlRE = /(?:[a-z][\w\-]+:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]|\((?:[^\s()<>]|(?:\([^\s()<>]+\)))*\))+(?:\((?:[^\s()<>]|(?:\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:\'\".,<>?«»“”‘’])/i
  # a little bit of magic to glue these regexps into a single pattern
  pats = [urlRE,hashtagRE,usernameRE].map (re) -> re.source
  # start with ^|\s because there's no \b before @user and #hash
  # but also use \b to allow (http://...)
  re = new RegExp('(^|\\b|\\s)(?:(' + pats.join(')|(') + '))', 'ig')
  # ok!
  return (input) ->
    input.replace re, (text,sp,url,hashtag,username) -> switch
      when url? then "#{sp}<a href='#{url}' target='_blank'>#{url}</a>"
      when hashtag? then "#{sp}<a href='https://twitter.com/search?q=#{encodeURIComponent hashtag}' target='_blank'>#{hashtag}</a>"
      when username? then "#{sp}<a href='https://twitter.com/#{encodeURIComponent username.slice(1)}' target='_blank'>#{username}</a>"
      else text # shouldn't really ever reach here

# See https://dev.twitter.com/streaming/overview/request-parameters#track
hashtag = 'mysteryhunt,mitmysteryhunt'
twit.stream 'statuses/filter', {track: hashtag}, (stream) ->
  console.log "Listening to #{hashtag} on twitter"
  stream.on 'data', (data) ->
    return if data.retweeted_status? # don't report retweets
    unless data.user? # weird bug we saw
      console.log 'WEIRD TWIT!', data
      return
    console.log "Twitter! @#{data.user.screen_name} #{data.text}"
    text = linkify data.text
    Meteor.call 'newMessage',
      nick: 'via twitter'
      action: 'true'
      body: "<a href='https://twitter.com/#{data.user.screen_name}'>@#{data.user.screen_name}</a> <a href='https://twitter.com/#{data.user.screen_name}/status/#{data.id_str}' target='_blank'>says:</a> #{text}"
      bodyIsHtml: true
      bot_ignore: true

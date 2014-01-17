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

hashtag = '#mysteryhunt'
twit.stream 'statuses/filter', {track: hashtag}, (stream) ->
  console.log "Listening to #{hashtag} on twitter"
  stream.on 'data', (data) ->
    console.log "@#{data.user.screen_name} #{data.text}"

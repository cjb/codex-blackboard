# emoji name to codepoint map, from https://github.com/github/gemoji
# compatible with https://www.webpagefx.com/tools/emoji-cheat-sheet/
# kept server-side so we don't have to send the whole mapping to every
# client.
import * as db from './emoji.json'

emojiMap = new Map()
db.default.forEach (entry) ->
  entry.aliases.forEach (a) ->
    emojiMap.set(a, entry.emoji)

# We might consider substituting an <i> tag from
# http://ellekasai.github.io/twemoji-awesome/
# on client-side to render these?  But for server-side storage
# and chat bandwidth, definitely better to have direct unicode
# stored in the DB.
share.emojify = (s) ->
  s.replace /:([+]?[-a-z0-9_]+):/g, (full, name) ->
   emojiMap.get(name) or full

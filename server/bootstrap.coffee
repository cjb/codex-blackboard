# if the database is empty on server start, create some sample data.
SAMPLE_DATA = [
  name: "Mega man"
  rounds: [
    name: "Bebop man round"
    tags: [
      { name: "Transform", value: "HELICAL via ALPHA DECAY" }
      { name: "Hint", value: "answers contain notes (do, re, mi)" }
      { name: "Meta answer", value: "BLUE SHIFT" }
    ]
    chats: [
      { nick: "cscott", body: "This round is wack." }
    ]
    puzzles: [
      name: "Meta testing"
      answer: "BACKSOLVER"
      chats: [
        { nick: "cscott", body: "Let's do some Meta Testing!" }
      ]
    ,
      name: "Timbales"
      answer: "ACTAPILATI"
    ,
      name: "Famous faces"
      answer: "FAMILYNAME"
    ,
      name: "Favourites"
      answer: "CRESCENDOS"
    ,
      name: "One more try"
      answer: "BELLADONNA"
      tags: [
        { name: "Type", value: "crossword" }
      ]
    ]
  ,
    name: "Bio man round"
    tags: [
      { name: "Transform", value: "IVY via BLUESHIFT" }
    ]
    puzzles: [
      name: "Stuff nerd people like"
      tags: [
        { name: "status", value: "Needs extraction (fresh eyes)" }
      ]
    ,
      name: "Recombination"
      answer: "CLAP"
    ,
      name: "Life of the party"
      answer: "KILLER COLD"
    ,
      name: "The eternal struggle"
      answer: "CREEPING INFECTION"
    ,
      name: "Pesky bugs"
      answer: "PLAGUE"
      tags: [
        { name: "Extra", value: "free puzzle" }
      ]
    ]
  ,
    name: "Blackberry man round"
    tags: [
      { name: "Transform", value: "BAKER via ODDSFINDER" }
      { name: "Meta answer", value: "TELEGRAPH SWITCH" }
    ]
    puzzles: [
      name: "Redundant obsolescence"
      answer: "ANGORA"
    ,
      name: "Powder monkey"
      tags: [
        { name: "status", value: "Stuck needs fresh eyes" }
      ]
    ,
      name: "N-tris"
      answer: "QUEUER"
    ,
      name: "Expletive deleted"
      answer: "SMILEY"
    ,
      name: "The least you could do is phone me"
      answer: "SOURCE"
    ]
  ,
    name: "Craps man round"
    tags: [
      { name: "Transform", value: "SCRAPS via WORD SWORD" }
      { name: "Meta answer", value: "ODDSFINDER" }
    ]
    puzzles: [
      name: "Scrambling attributes yields conundrum"
      answer: "THE QUEEN OF SPADES"
    ,
      name: "Good vibrations"
      answer: "AMORES PERROS"
    ,
      name: "Genius test"
      answer: "DEAD MANS CHEST"
    ,
      name: "Basic knowledge"
      answer: "SEABISCUIT"
    ,
      name: "Good times in the casino"
      answer: "THE JOY LUCK CLUB"
      tags: [
        { name: "Type", value: "crossword" }
      ]
    ]
  ,
    name: "Minus man round"
    tags: [
      { name: "Transform", value: "IMAGO via TELEGRAPH SWITCH" }
      { name: "Meta answer", value: "ALPHA DECAY" }
    ]
    puzzles: [
      name: "Magnitude"
      answer: "INEQUALITY"
    ,
      name: "Metrology"
      answer: "JOSEPH"
      tags: [
        { name: "Type", value: "image" }
      ]
    ,
      name: "Nik-holey"
      answer: "FACADE"
    ,
      name: "Games"
      answer: "SECURE"
    ,
      name: "You shall understand what hath befallen"
      answer: "SWAYINGS"
    ]
  ,
    name: "Stagecraft man round"
    tags: [
      { name: "Transform", value: "SERF via removing DNA" }
      { name: "Meta answer", value: "WORD SWORD" }
    ]
    puzzles: [
      name: "The cats meow"
      answer: "BASSET"
    ,
      name: "Rocky horror"
      answer: "ELBOW"
    ,
      name: "Pointillisme"
      tags: [
        { name: "status", value: "Needs doc help and extraction" }
      ]
    ,
      name: "Where's antoinette"
      answer: "BOTTOM"
    ,
      name: "The writing on the wall"
      answer: "TAURUS"
    ]
  ,
    name: "Dr wily's really really really long fortress round" # slight hack
    tags: [
      { name: "Meta answer", value: "ZELDA" }
    ]
    puzzles: [
      name: "Fortress puzzle"
      answer: "WILYCOYOTE"
    ]
  ]
,
  name: "Zelda"
  rounds: [
    name: "Zelda round"
    tags: [
      { name: "Meta answer", value: "Inspiration: POLLINATE, Holiness: CREATURES, Fellowship: REGAL RING" }
      { name: "Unused answer", value: "PINTS OF LAGER" }
    ]
    puzzles: [
      name: "Making the possible"
      answer: "ABSOLUTE AUTHORITY/THE FIRST NOEL/FLOOD"
    ,
      name: "Forsaken fortress"
      answer: "CANADA/DIORAMIC/?"
    ,
      name: "Build your own acrostic"
      answer: "PRERINSE/FOURQUARTETS/CHASTITY"
    ,
      name: "Counting the ways"
      answer: "COLLIN CHOU/FOUR ROOMS/WEBISMS"
    ,
      name: "The word"
      answer: "THE RISE AND FALL OF THE THIRD REICH/GOALIES/?"
    ,
      name: "The light world"
      answer: "GRANOLA/?/?"
    ,
      name: "Song of birds"
      answer: "KEPLERS THIRD LAW/ST EDWARDS CHAIR/BARROOM"
    ,
      name: "Execution grounds"
      answer: "FLAG DAY/?/?"
    ,
      name: "The crypt"
      answer: "THEODORO/ILIUM/PAS DE DEUX"
    ]
  ,
    name: "Ganon's lair round"
    tags: [
      { name: "Meta answer", value: "NERF SWORD" }
    ]
    puzzles: [
      name: "Ganon's lair puzzle"
    ]
  ]
,
  name: "Civilization"
  rounds: [
    name: "Civilization round"
    puzzles: [
      name: "A modern palimpsest"
      answer: "ORCHID"
      tags: [
        { name: "Technology", value: "The scroll" }
      ]
    ,
      name: "Technological crisis at shikakuro farms"
      answer: "INGRID"
      tags: [
        { name: "Technology", value: "Agriculture" }
      ]
    ,
      name: "Charm school"
      answer: "GOOIER"
      tags: [
        { name: "Technology", value: "Exogamy" }
      ]
    ,
      name: "Showcase"
      answer: "HEXAGONAL"
      tags: [
        { name: "Technology", value: "Mathematics" }
      ]
    ,
      name: "Drafting table"
      answer: "MERCURY"
      tags: [
        { name: "Technology", value: "Draftsmanship" }
      ]
    ,
      name: "Racking your brains"
      tags: [
        { name: "Idea", value: "answer must contain two Fs and no other doubled letters (nonconsecutive is okay)" }
        { name: "Technology", value: "The Wheel" }
        { name: "status", value: "Needs extraction" }
      ]
    ,
      name: "Crowd's chant"
      answer: "AMERICAN"
      tags: [
        { name: "Technology", value: "Gladiatorial Combat" }
        { name: "Extra", value: "free puzzle" }
      ]
    ,
      name: "Hints with a bit of love"
      answer: "WANDERING"
      tags: [
        { name: "Technology", value: "and literature" }
      ]
    ,
      name: "Letter bank"
      answer: "UPKEEP"
      tags: [
        { name: "Technology", value: "plant-based ink" }
      ]
    ,
      name: "This should be easy"
      answer: "AUTUMN"
      tags: [
        { name: "Idea", value: "answer must contain two Us and no other doubled letters (nonconsecutive is okay)" }
        { name: "Technology", value: "Epic Poetry" }
        { name: "status", value: "Lowest priority" }
      ]
    ,
      name: "Soooo cute"
      answer: "LARGE CRABGRASS"
      tags: [
        { name: "Technology", value: "Procrastinating" }
      ]
    ,
      name: "Advanced maths"
      answer: "CORNCAKE"
      tags: [
        { name: "Technology", value: "Philosophy" }
      ]
    ,
      name: "Painted potsherds"
      answer: "MALTESE FALCON"
      tags: [
        { name: "Technology", value: "Stoneware" }
      ]
    ,
      name: "Cheaters never prosper"
      answer: "BADMINTON"
      tags: [
        { name: "Technology", value: "Legal System" }
      ]
    ,
      name: "The doors of cambridge"
      answer: "COLONEL"
      tags: [
        { name: "Technology", value: "doors" }
      ]
    ,
      name: "Literacy collection"
      answer: "AIRBAG"
      tags: [
        { name: "Technology", value: "literacy" }
      ]
    ,
      name: "Amateur hour"
      answer: "STIRFRIED"
      tags: [
        { name: "Technology", value: "Alchemy" }
      ]
    ,
      name: "Puzzle box"
      tags: [
        { name: "status", value: "Needs extraction" }
        { name: "Technology", value: "invention" }
      ]
    ,
      name: "Sufficiently advanced technology"
      answer: "TRISKELION"
      tags: [
        { name: "Technology", value: "Trading" }
      ]
    ,
      name: "Part of speech"
      answer: "CONRAD"
      tags: [
        { name: "Technology", value: "oratory" }
      ]
    ,
      name: "Inventory quest"
      answer: "BURDEN"
      tags: [
        { name: "Technology", value: "Private Property" }
      ]
    ,
      name: "Laureate"
      answer: "FRIEND"
      tags: [
        { name: "Technology", value: "Carbon Nanotubules" }
      ]
    ,
      name: "The sport of princesses"
      answer: "SUFFOLK DOWNS"
      tags: [
        { name: "Technology", value: "monarchy" }
      ]
    ,
      name: "Fascinating kids"
      tags: [
        { name: "status", value: "Lowest priority" }
        { name: "Technology", value: "Social Clubs" }
      ]
    ]
  ,
    name: "Wonders round"
    tags: [
      { name: "Meta answer", value: "ORANGE" }
    ]
    puzzles: [
    ]
  ]
]
SAMPLE_CHATS = [
  nick: "cscott"
  body: "Have we found the coin yet?  Seriously."
,
  nick: "cscott"
  body: "This is a very very long line which should hopefully wrap and that will show that we're doing all this correctly. Let's keep going here. More and more stuff! Wow."
]

Meteor.startup ->
  if RoundGroups.find().count() is 0
    # note that Meteor.call is async... this causes some slight issues...
    WHO='cscott'
    extend = (a,b) ->
      r = Object.create(null)
      for own key, value of a
        r[key] = value
      for own key, value of b
        r[key] = value
      return r
    for roundgroup in SAMPLE_DATA
      Meteor.call "newRoundGroup", extend(roundgroup,{who:WHO,rounds:null}), (error, rg) ->
        throw error if error
        for round in roundgroup.rounds
          Meteor.call "newRound", extend(round,{who:WHO,puzzles:null}), (error, r) ->
            throw error if error
            Meteor.call "addRoundToGroup", r, rg, WHO
            for chat in (round.chats or [])
              chat.room_name = "round/" + r._id
              Meteor.call "newMessage", chat
            for puzzle in round.puzzles
              Meteor.call "newPuzzle", extend(puzzle,{who:WHO}), (error, p) ->
                throw error if error
                Meteor.call "addPuzzleToRound", p, r, WHO
                if puzzle.answer
                  Meteor.call "setAnswer", p._id, puzzle.answer, WHO
                for chat in (puzzle.chats or [])
                  chat.room_name = "puzzle/" + p._id
                  Meteor.call "newMessage", chat
    # add some general chats
    for chat in SAMPLE_CHATS
      chat.room_name = "general/0"
      Meteor.call "newMessage", chat

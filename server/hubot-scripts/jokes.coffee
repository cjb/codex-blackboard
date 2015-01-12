# Description:
#   Tell knock-knock jokes
#
# Commands:
#   bot: tell me a joke
#   bot: knock-knock

JOKES = []
pick_a_joke = () -> JOKES[ Math.floor(Math.random() * JOKES.length) ]
ucfirst = (s) -> (s.replace /^./, (match) -> match.toUpperCase())

share.hubot.jokes = (robot) ->
  key = (k,msg) -> "#{k}:#{msg.envelope.user.id}:#{msg.envelope.room}"
  get = (k,msg) ->
    v = robot.brain.get key(k,msg)
    return unless v?.expires?
    return v if Date.now() < v.expires
    robot.brain.remove key(k,msg)
    return
  set = (k,msg,val) ->
    val.expires = Date.now() + (5 * 60 * 1000) # five minutes
    robot.brain.set key(k,msg), val
  remove = (k,msg) -> robot.brain.remove key(k,msg)
  ALL = new RegExp()

  robot.commands.push 'bot tell me a joke'
  robot.respond /\b(tell me (\w+ )*joke|i (don\'t|do not) get it)\b/i, (msg) ->
     joke = pick_a_joke()
     set 'JOKE', msg, { answer: joke.a }
     msg.reply joke.q
     return msg.finish()
  robot.hear ALL, (msg) ->
     context = get 'JOKE', msg
     return unless context?
     remove 'JOKE', msg
     msg.reply context.answer
     return msg.finish()

  robot.commands.push 'bot knock-knock'
  robot.respond /\bknock\s*[-, ]\s*knock\b/i, (msg) ->
     set 'KK', msg, { start: true }
     msg.reply "Who's there?"
     return msg.finish()
  robot.hear /^\s*(?:[@]?(?:codex)?bot[:,]?\s*)?(\S.*)/i, (msg) ->
     context = get 'KK', msg
     if context?.start
       what = msg.match[1]
       set 'KK', msg, { what: what }
       msg.reply "#{ucfirst(what)} who?"
       return msg.finish()
     if context?.what?
       remove 'KK', msg
       msg.reply msg.random [
         "Very funny, wise guy."
         "Ha ha ha ha ha ha ha!"
         "Er, ok."
         "Snort!"
         "I don't get it: #{context.what}?"
         "Hee-hee."
         "ROTFL!"
         ":-D"
         "The boys down at the robot factory will love that."
         "I'll have to remember that one."
         "Does not compute.  Was that supposed to be funny?"
         "Damnit, Jim!  I'm a robot, not a laughing machine!"
         "Snicker."
         "Giggle!"
         "I would raise an eyebrow, if I had one."
         "Was that supposed to be a puzzle?"
       ]
       return msg.finish()

# Joke list!
"""
Q:	"What is the burning question on the mind of every dyslexic existentialist?"
A:	"Is there a dog?"
%
Q:	Are we not men?
A:	We are Vaxen.
%
Q:	Do you know what the death rate around here is?
A:	One per person.
%
Q:	Heard about the <ethnic> who couldn't spell?
A:	He spent the night in a warehouse.
%
Q:	How can you tell when a Burroughs salesman is lying?
A:	When his lips move.
%
Q:	How did you get into artificial intelligence?
A:	Seemed logical -- I didn't have any real intelligence.
%
Q:	How do you catch a unique rabbit?
A:	Unique up on it!
%
Q:	How do you keep a moron in suspense?
A:      
%
Q:	How do you know when you're in the <ethnic> section of Vermont?
A:	The maple sap buckets are hanging on utility poles.
%
Q:	How do you play religious roulette?
A:	You stand around in a circle and blaspheme and see who gets struck by lightning first.
%
Q:	How do you save a drowning lawyer?
A:	Throw him a rock.
%
Q:	How do you stop an elephant from charging?
A:	Take away his credit cards.
%
Q:	How does a hacker fix a function which doesn't work for all of the elements in its domain?
A:	He changes the domain.
%
Q:	How many Bell Labs Vice Presidents does it take to change a light bulb?
A:	That's proprietary information.  Answer available from AT&T on payment of license fee (binary only).
%
Q:	How many bureaucrats does it take to screw in a light bulb?
A:	Two.  One to assure everyone that everything possible is being done while the other screws the bulb into the water faucet.
%
Q:	How many Californians does it take to screw in a light bulb?
A:	Five.  One to screw in the light bulb and four to share the experience.  (Actually, Californians don't screw in light bulbs, they screw in hot tubs.)
%
Q:	How many Oregonians does it take to screw in a light bulb?
A:	Three.  One to screw in the light bulb and two to fend off all those Californians trying to share the experience.
%
Q:	How many college football players does it take to screw in a light bulb?
A:	Only one, but he gets three credits for it.
%
Q:	How many DEC repairman does it take to fix a flat?
A:	Five; four to hold the car up and one to swap tires.
%
Q:	How many elephants can you fit in a VW Bug?
A:	Four.  Two in the front, two in the back.
%
Q:	How can you tell if an elephant is in your refrigerator?
A:	There's a footprint in the mayo.
%
Q:	How many existentialists does it take to screw in a light bulb?
A:	Two.  One to screw it in and one to observe how the light bulb itself symbolizes a single incandescent beacon of subjective reality in a netherworld of endless absurdity reaching out toward a maudlin cosmos of nothingness.
%
Q:	How many gradual (sorry, that's supposed to be "graduate") students does it take to screw in a light bulb?
A:	"I'm afraid we don't know, but make my stipend tax-free, give my advisor a $30,000 grant of the taxpayer's money, and I'm sure he can tell me how to do the gruntwork for him so he can take the credit for answering this incredibly vital question."
%
Q:	How many hardware engineers does it take to change a light bulb?
A:	None.  We'll fix it in software.
%
Q:	How many system programmers does it take to change a light bulb?
A:	None.  The application can work around it.
%
Q:	How many software engineers does it take to change a light bulb?
A:	None.  We'll document it in the manual.
%
Q:	How many tech writers does it take to change a light bulb?
A:	None.  The user can figure it out.
%
Q:	How many Harvard MBA's does it take to screw in a light bulb?
A:	Just one.  He grasps it firmly and the universe revolves around him.
%
Q:	How many IBM 370's does it take to execute a job?
A:	Four, three to hold it down, and one to rip its head off.
%
Q:	How many IBM CPU's does it take to do a logical right shift?
A:	33.  1 to hold the bits and 32 to push the register.
%
Q:	How many IBM types does it take to change a light bulb?
A:	Fifteen.  One to do it, and fourteen to write document number GC7500439-0001, Multitasking Incandescent Source System Facility, of which 10% of the pages state only "This page intentionally left blank", and 20% of the definitions are of the form "A:..... consists of sequences of non-blank characters separated by blanks".
%
Q:	How many journalists does it take to screw in a light bulb?
A:	Three.  One to report it as an inspired government program to bring light to the people, one to report it as a diabolical government plot to deprive the poor of darkness, and one to win a Pulitzer prize for reporting that Electric Company hired a light bulb-assassin to break the bulb in the first place.
%
Q:	How many lawyers does it take to change a light bulb?
A:	One.  Only it's his light bulb when he's done.
%
Q:	How many lawyers does it take to change a light bulb?
A:	Whereas the party of the first part, also known as "Lawyer", and the party of the second part, also known as "Light Bulb", do hereby and forthwith agree to a transaction wherein the party of the second part shall be removed from the current position as a result of failure to perform previously agreed upon duties, i.e., the lighting, elucidation, and otherwise illumination of the area ranging from the front (north) door, through the entryway, terminating at an area just inside the primary living area, demarcated by the beginning of the carpet, any spillover illumination being at the option of the party of the second part and not required by the aforementioned agreement between the parties. The aforementioned removal transaction shall include, but not be limited to, the following.  The party of the first part shall, with or without elevation at his option, by means of a chair, stepstool, ladder or any other means of elevation, grasp the party of the second part and rotate the party of the second part in a counter-clockwise direction, this point being tendered non-negotiable.  Upon reaching a point where the party of the second part becomes fully detached from the receptacle, the party of the first part shall have the option of disposing of the party of the second part in a manner consistent with all relevant and applicable local, state and federal statutes. Once separation and disposal have been achieved, the party of the first part shall have the option of beginning installation.  Aforesaid installation shall occur in a manner consistent with the reverse of the procedures described in step one of this self-same document, being careful to note that the rotation should occur in a clockwise direction, this point also being non-negotiable. The above described steps may be performed, at the option of the party of the first part, by any or all agents authorized by him, the objective being to produce the most possible revenue for the Partnership.
%
Q:	How many lawyers does it take to change a light bulb?
A:	You won't find a lawyer who can change a light bulb.  Now, if you're looking for a lawyer to screw a light bulb...
%
Q:	How many marketing people does it take to change a light bulb?
A:	I'll have to get back to you on that.
%
Q:	How many Martians does it take to screw in a light bulb?
A:	One and a half.
%
Q:	How many Marxists does it take to screw in a light bulb?
A:	None:  The light bulb contains the seeds of its own revolution.
%
Q:	How many mathematicians does it take to screw in a light bulb?
A:	One.  He gives it to six Californians, thereby reducing the problem to the earlier joke.
%
Q:	How many members of the U.S.S. Enterprise does it take to change a light bulb?
A:	Seven.  Scotty has to report to Captain Kirk that the light bulb in the Engineering Section is getting dim, at which point Kirk will send Bones to pronounce the bulb dead (although he'll immediately claim that he's a doctor, not an electrician).  Scotty, after checking around, realizes that they have no more new light bulbs, and complains that he "canna" see in the dark.  Kirk will make an emergency stop at the next uncharted planet, Alpha Regula IV, to procure a light bulb from the natives, who, are friendly, but seem to be hiding something. Kirk, Spock, Bones, Yeoman Rand and two red shirt security officers beam down to the planet, where the two security officers are promply killed by the natives, and the rest of the landing party is captured. As something begins to develop between the Captain and Yeoman Rand, Scotty, back in orbit, is attacked by a Klingon destroyer and must warp out of orbit.  Although badly outgunned, he cripples the Klingon and races back to the planet in order to rescue Kirk et. al. who have just saved the natives' from an awful fate and, as a reward, been given all light bulbs they can carry.  The new bulb is then inserted and the Enterprise continues on its five year mission.
%
Q:	How many Oregonians does it take to screw in a light bulb?
A:	Three.  One to screw in the light bulb and two to fend off all those Californians trying to share the experience.
%
Q:	How many psychiatrists does it take to change a light bulb?
A:	Only one, but it takes a long time, and the light bulb has to really want to change.
%
Q:	How many supply-siders does it take to change a light bulb?
A:	None.  The darkness will cause the light bulb to change by itself.
%
Q:	How many surrealists does it take to change a light bulb?
A:	Two, one to hold the giraffe, and the other to fill the bathtub with brightly colored machine tools.
%
Q:	How many WASPs does it take to change a light bulb?
A:	One.
%
Q:	How many Zen masters does it take to screw in a light bulb?
A:	None.  The Universe spins the bulb, and the Zen master stays out of the way.
%
Q:	How much does it cost to ride the Unibus?
A:	2 bits.
%
Q:	How was Thomas J. Watson buried?
A:	9 edge down.
%
Q:	Know what the difference between your latest project and putting wings on an elephant is?
A:	Who knows?  The elephant *might* fly, heh, heh...
%
Q:	Minnesotans ask, "Why aren't there more pharmacists from Alabama?"
A:	Easy.  It's because they can't figure out how to get the little bottles into the typewriter.
%
Q:	What do agnostic, insomniac dyslexics do at night?
A:	Stay awake and wonder if there's a dog.
%
Q:	What do little WASPs want to be when they grow up?
A:	The very best person they can possibly be.
%
Q:	What do they call the alphabet in Arkansas?
A:	The impossible dream.
%
Q:	What do Winnie the Pooh and John the Baptist have in common?
A:	The same middle name.
%
Q:	What do you call 15 blondes in a circle?
A:	A dope ring.
%
Q:	Why do blondes put their hair in ponytails?
A:	To cover up the valve stem.
%
Q:	What do you call a blind pre-historic animal?
A:	Diyathinkhesaurus.
%
Q:	What do you call a blind pre-historic animal with a dog?
A:	Diyathinkhesaurus Rex.
%
Q:	What do you call a blind, deaf-mute, quadraplegic Virginian?
A:	Trustworthy.
%
Q:	What do you call a boomerang that doesn't come back?
A:	A stick.
%
Q:	What do you call a half-dozen Indians with Asian flu?
A:	Six sick Sikhs (sic).
%
Q:	What do you call a principal female opera singer whose high C is lower than those of other principal female opera singers?
A:	A deep C diva.
%
Q:	What do you call a WASP who doesn't work for his father, isn't a lawyer, and believes in social causes?
A:	A failure.
%
Q:	What do you call the money you pay to the government when you ride into the country on the back of an elephant?
A:	A howdah duty.
%
Q:	What do you call the scratches that you get when a female sheep bites you?
A:	Ewe nicks.
%
Q:	What do you get when you cross a mobster with an international standard?
A:	You get someone who makes you an offer that you can't understand!
%
Q:	What do you get when you cross the Godfather with an attorney?
A:	An offer you can't understand.
%
Q:	What do you have when you have a lawyer buried up to his neck in sand?
A:	Not enough sand.
%
Q:	What do you say to a New Yorker with a job?
A:	Big Mac, fries and a Coke, please!
%
Q:	What does a WASP Mom make for dinner?
A:	A crisp salad, a hearty soup, a lovely entree, followed by a delicious dessert.
%
Q:	What does friendship among Soviet nationalities mean?
A:	It means that the Armenians take the Russians by the hand; the Russians take the Ukrainians by the hand; the Ukranians take the Uzbeks by the hand; and they all go and beat up the Jews.
%
Q:	What does it say on the bottom of Coke cans in North Dakota?
A:	Open other end.
%
Q:	What happens when four WASPs find themselves in the same room?
A:	A dinner party.
%
Q:	What is green and lives in the ocean?
A:	Moby Pickle.
%
Q:	What is orange and goes "click, click?"
A:	A ball point carrot.
%
Q:	What is printed on the bottom of beer bottles in Minnesota?
A:	Open other end.
%
Q:	What is purple and commutes?
A:	An Abelian grape.
%
Q:	What is purple and concord the world?
A:	Alexander the Grape.
%
Q:	What is the difference between a duck?
A:	One leg is both the same.
%
Q:	What is the difference between Texas and yogurt?
A:	Yogurt has culture.
%
Q:	What is the sound of one cat napping?
A:	Mu.
%
Q:	What lies on the bottom of the ocean and twitches?
A:	A nervous wreck.
%
Q:	What looks like a cat, flies like a bat, brays like a donkey, and plays like a monkey?
A:	Nothing.
%
Q:	What's a light-year?
A:	One-third less calories than a regular year.
%
Q:	What's a WASP's idea of open-mindedness?
A:	Dating a Canadian.
%
Q:	What's buried in Grant's tomb?
A:	A corpse.
%
Q:	What's hard going in and soft and sticky coming out?
A:	Chewing gum.
%
Q:	What's tan and black and looks great on a lawyer?
A:	A doberman.
%
Q:	What's the contour integral around Western Europe?
A:	Zero, because all the Poles are in Eastern Europe! (Addendum: Actually, there ARE some Poles in Western Europe, but they are removable!)
%
Q:	An English mathematician (I forgot who) was asked by his very religious colleague: Do you believe in one God?
A:	Yes, up to isomorphism!
%
Q:	What is a compact city?
A:	It's a city that can be guarded by finitely many near-sighted policemen!
%
Q:	What's the difference betweeen Windows and the Graf Zeppelin?
A:	The Graf Zeppelin represented cutting edge technology for its time.
%
Q:	What's the difference between a dead dog in the road and a dead lawyer in the road?
A:	There are skid marks in front of the dog.
%
Q:	What's the difference between a duck and an elephant?
A:	You can't get down off an elephant.
%
Q:	What's the difference between a Mac and an Etch-a-Sketch?
A:	You don't have to shake the Mac to clear the screen.
%
Q:	What's the difference between an Irish wedding and an Irish wake?
A:	One less drunk.
%
Q:	What's the difference between Bell Labs and the Boy Scouts of America?
A:	The Boy Scouts have adult supervision.
%
Q:	What's the difference between the 1950's and the 1980's?
A:	In the 80's, a man walks into a drugstore and states loudly, "I'd like some condoms," and then, leaning over the counter, whispers, "and some cigarettes."
%
Q:	What's the difference between Windows Vista and the Titanic?
A:	The Titanic had a band.
%
Q:	What's tiny and yellow and very, very, dangerous?
A:	A canary with the super-user password.
%
Q:	What's yellow, and equivalent to the Axiom of Choice?
A:	Zorn's Lemon.
%
Q:	Where's the Lone Ranger take his garbage?
A:	To the dump, to the dump, to the dump dump dump!
%
Q:	What's the Pink Panther say when he steps on an ant hill?
A:	Dead ant, dead ant, dead ant dead ant dead ant...
%
Q:	Who cuts the grass on Walton's Mountain?
A:	Lawn Boy.
%
Q:	Why did Menachem Begin invade Lebanon?
A:	To impress Jodie Foster.
%
Q:	Why did the astrophysicist order three hamburgers?
A:	Because he was hungry.
%
Q:	Why did the chicken cross the road?
A:	He was giving it last rites.
%
Q:	Why did the chicken cross the road?
A:	To see his friend Gregory peck.
%
Q:	Why did the chicken cross the playground?
A:	To get to the other slide.
%
Q:	Why did the germ cross the microscope?
A:	To get to the other slide.
%
Q:	Why did the lone ranger kill Tonto?
A:	He found out what "kimosabe" really means.
%
Q:	Why did the programmer call his mother long distance?
A:	Because that was her name.
%
Q:	Why did the tachyon cross the road?
A:	Because it was on the other side.
%
Q:	Why did the WASP cross the road?
A:	To get to the middle.
%
Q:	Why do firemen wear red suspenders?
A:	To conform with departmental regulations concerning uniform dress.
%
Q:	Why do mountain climbers rope themselves together?
A:	To prevent the sensible ones from going home.
%
Q:	Why do people who live near Niagara Falls have flat foreheads?
A:	Because every morning they wake up thinking "What *is* that noise? Oh, right, *of course*!
%
Q:	Why do the police always travel in threes?
A:	One to do the reading, one to do the writing, and the other keeps an eye on the two intellectuals.
%
Q:	Why do WASPs play golf ?
A:	So they can dress like pimps.
%
Q:	Why does Washington have the most lawyers per capita and New Jersey the most toxic waste dumps?
A:	God gave New Jersey first choice.
%
Q:	Why don't lawyers go to the beach?
A:	The cats keep trying to bury them.
%
Q:	Why don't Scotsmen ever have coffee the way they like it?
A:	Well, they like it with two lumps of sugar.  If they drink it at home, they only take one, and if they drink it while visiting, they always take three.
%
Q:	Why haven't you graduated yet?
A:	Well, Dad, I could have finished years ago, but I wanted my dissertation to rhyme.
%
Q:	Why is Christmas just like a day at the office?
A:	You do all of the work and the fat guy in the suit gets all the credit.
%
Q:	Why is it that Mexico isn't sending anyone to the '84 summer games?
A:	Anyone in Mexico who can run, swim or jump is already in LA.
%
Q:	Why is it that the more accuracy you demand from an interpolation function, the more expensive it becomes to compute?
A:	That's the Law of Spline Demand.
%
Q:	Why is Poland just like the United States?
A:	In the United States you can't buy anything for zlotys and in Poland you can't either, while in the U.S. you can get whatever you want for dollars, just as you can in Poland. 	(being told in Poland, 1987)
%
Q:	Why should you always serve a Southern Carolina football man soup in a plate?
A:	'Cause if you give him a bowl, he'll throw it away.
%
Q:	Why was Stonehenge abandoned?
A:	It wasn't IBM compatible.
""".split(/%\n/).forEach (j) ->
  m = /^Q:\s+(.*)\nA:\s+(.*)\n$/.exec j
  return unless m?
  JOKES.push
    q: m[1]
    a: m[2]

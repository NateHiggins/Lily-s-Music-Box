class_name CaseLibrary
## The Case Network as data. `call_interface.gd` is the projector; this is
## the film.
##
## Every case is the same shape, because the support desk only ever offers
## three verbs — split a signal apart, hold a piece of it, push that piece
## into the building — and a case is what those verbs MEAN this time. Case
## 01 splits a caller's room tone off her voice; Case 02 splits her ceiling
## off our risers; Case 03 splits a woman off her own imitation. Keeping the
## verbs fixed is what lets the player arrive at case three already fluent,
## and it is why the runner never needs to know which case it is playing.
##
## Cases diverge where it matters: what the responses are, and what the
## building is left like afterwards.
##
## A beat is a one-key dictionary, played in order:
##   {"delay": sec}              wait (scaled by the runner's `fast` flag)
##   {"say": text}               the caller speaks
##   {"resident": text}          the matched resident speaks, from the building
##   {"hint": text}              operator-console analysis line
##   {"infection": v}            set building infection immediately
##   {"infection_to": [v, sec]}  tween it (killed if an outcome interrupts)
##   {"origin": node_id}         move the conductor's origin (must be a real
##                               acoustic graph node — a typo here is silent)
##   {"propagate": [node, i, accent, db]}   inject one event at a node
##   {"mutate": true}            warp the motif permanently
##   {"vocal": pitch}            the operator's own hum
##   {"reveal": prop_name}       a lasting change to the building
##   {"flag": name}              a lasting change to the desk//world state
##   {"respond": hint}           open the response window and start the clock

## Design rule from case_network_batch_01.md: a case is weak if it could be
## solved by choosing the obviously compassionate option. Each response
## below is defensible and each one costs something.
const CASES := [
{
	"id": "4471",
	"caller": "M. CHEN",
	"complaint": "SPEAKER ANSWERS BEFORE I ASK",
	"resident": "MINA VALE · 2A",
	"desk_prompt": "Sit at the support desk",
	"tools": {
		"isolate": "ISOLATE NOISE",
		"capture": "CAPTURE LOOP",
		"route": "ROUTE → DESK SPEAKERS",
	},
	"isolate_hint": "Background channel isolated. Listen to her breathing.",
	"capture_ready_hint":
		"Pattern registered: 4 events, 1 expected. [CAPTURE LOOP] to hold it.",
	"capture_hint":
		"Loop held: four marks, one empty slot. Route it to hear it in the room.",
	"ticks_to_capture": 6,
	"prompt": "THE PATTERN WAITS —",
	"silence_note": "(or say nothing)",
	"timeout": "silence",
	"responses": [
		{"id": "complete", "label": "COMPLETE IT"},
		{"id": "interrupt", "label": "INTERRUPT"},
	],
	"open": [
		{"delay": 1.5},
		{"say": "Thanks for staying on this late. It's the speaker — it answers before I finish asking."},
		{"delay": 0.8},
		{"say": "There's a clicking behind it too. That's just the pipes. Ignore that."},
		{"delay": 1.5},
		{"hint": "ANALYSIS: periodic transient on background channel — the same period as this building."},
	],
	"route": [
		{"origin": "F04_B_MONITOR_01"},
		{"infection_to": [0.6, 10.0]},
		{"hint": "Routing through desk speakers. Room response pending…"},
	],
	"transmission": [
		{"delay": 6.0},
		{"say": "Wait. I can hear knocking. Not here — through the phone. It's in YOUR room, isn't it?"},
		{"delay": 3.0},
		{"respond": "Every source stops at the same empty slot. It is waiting."},
	],
	"outcomes": {
		"complete": [
			{"hint": "You answered."},
			{"vocal": 1.0},
			{"delay": 0.9},
			{"propagate": ["F04_B_RADIATOR_01", 4, 1.0, 0.0]},
			{"infection": 0.85},
			{"delay": 1.6},
			{"say": "oh. the door was always there. i can see your room now."},
		],
		"interrupt": [
			{"hint": "You spoke over it."},
			{"vocal": 1.3},
			{"mutate": true},
			{"infection": 0.65},
			{"delay": 2.0},
			{"say": "There's another voice in my speaker now. It's answering for me."},
		],
		"silence": [
			{"hint": ""},
			{"infection_to": [0.25, 3.0]},
			{"delay": 3.5},
			{"propagate": ["F04_B_RADIATOR_01", 4, 1.0, -12.0]},
			{"infection": 0.5},
			{"delay": 1.4},
			{"say": "you left it unfinished. hold still — i finished it for you."},
		],
	},
},
{
	"id": "4482",
	"caller": "L. PRICE",
	"complaint": "FOOTSTEPS IN THE UNIT ABOVE — IT'S EMPTY",
	"resident": "OMAR BELL · 3B",
	"desk_prompt": "Take the waiting call",
	## Same three verbs, aimed at architecture instead of a voice. The
	## isolate here is vertical: his ceiling against our risers.
	"tools": {
		"isolate": "SPLIT CEILING / RISER",
		"capture": "CAPTURE THE ROUTE",
		"route": "ROUTE → HEATING RISER",
	},
	"isolate_hint":
		"Two sets of steps, a half-beat out of phase. The second set is not in his building.",
	"capture_ready_hint":
		"It is not pacing a room. It repeats a PATH. [CAPTURE THE ROUTE] to hold it.",
	"capture_hint":
		"Route held: nine marks, and it turns twice. Push it into the pipes to see where it goes.",
	"ticks_to_capture": 7,
	"prompt": "THE ROUTE IS WALKING —",
	"silence_note": "(or get up, and be standing where it ends)",
	"timeout": "stay",
	## Long enough to actually walk it: 4B is two floors above the corridor
	## the route ends in. At the desk-length 16 s this would be a door
	## closing in your face rather than a choice.
	"window": 150.0,
	## The one action in this case that should never have been a button.
	## Standing where the route ends is answered with your feet, and the
	## anchor is the door itself — so the place you have to be is, by
	## construction, exactly where the door is going to appear.
	"field": {
		"node": "F03_UTILITY_ANOMALY",
		"radius": 2.6,
		"response": "walk",
		"banner": "The route is still walking. It ends on three, west corridor.",
	},
	"responses": [
		{"id": "match", "label": "MATCH ITS TEMPO"},
		{"id": "against", "label": "WALK AGAINST IT"},
		{"id": "strike", "label": "STRIKE THE PIPES"},
	],
	"open": [
		{"delay": 1.5},
		{"say": "The unit above me is empty. Has been since the tenant went. I still hear him walking it."},
		{"delay": 0.9},
		{"say": "I went up there tonight. Stood in the middle of the floor. They were still above me."},
		{"delay": 1.4},
		{"hint": "ANALYSIS: two transient sources, near-identical period. One of them is our riser."},
	],
	"route": [
		{"origin": "F03_B_RADIATOR_01"},
		{"infection_to": [0.55, 9.0]},
		{"hint": "In the pipes. Third-floor riser carrying it east."},
	],
	"transmission": [
		{"delay": 4.0},
		{"resident": "Nine and a turn. Nine and a turn. That's not a man pacing, that's a man being SHOWN something."},
		{"delay": 3.0},
		{"propagate": ["F03_D_RADIATOR_01", 2, 0.9, -4.0]},
		{"say": "It stopped. It's waiting at the end of my hall. Is it waiting for you?"},
		{"delay": 2.0},
		{"respond": "It ends two floors below you, in your own west corridor — a stretch longer than the building is wide. Answer from the desk, or go down and be standing in it."},
	],
	"outcomes": {
		## Every branch leaves the same door, because the door is what the
		## route was FOR. What changes is what the building learned about
		## whether you can be led.
		"match": [
			{"hint": "You walked it at its own tempo."},
			{"delay": 1.2},
			{"propagate": ["F03_D_RADIATOR_01", 4, 1.0, 0.0]},
			{"infection": 0.72},
			{"delay": 1.4},
			{"say": "My door's open. You're standing at the end of my hallway. We are not in the same CITY."},
			{"delay": 1.0},
			{"reveal": "F03_UTILITY_ANOMALY"},
			{"resident": "There's a door in my hall that isn't on my plans. I'm not opening it without a work order."},
		],
		"against": [
			{"hint": "You walked into it."},
			{"vocal": 0.86},
			{"mutate": true},
			{"infection": 0.6},
			{"delay": 2.0},
			{"say": "It went quiet. Then it started again from the other end. It's learning the way back."},
			{"delay": 1.0},
			{"reveal": "F03_UTILITY_ANOMALY"},
			{"resident": "Door's on the wrong side of the hall now. Same door. I checked twice."},
		],
		"strike": [
			{"hint": "You hit the riser and gave it a different way to go."},
			{"propagate": ["F03_B_RADIATOR_01", 1, 1.0, 3.0]},
			{"mutate": true},
			{"infection": 0.5},
			{"delay": 2.2},
			{"say": "Whatever you just did, it went somewhere else. Somebody else's ceiling now."},
			{"delay": 1.0},
			{"reveal": "F03_UTILITY_ANOMALY"},
			{"resident": "You rerouted it into MY floor. Thanks for that. There's a door here now."},
		],
		## Answered on foot: the player left the desk mid-call, went down two
		## floors, and was standing in the corridor when the route arrived.
		"walk": [
			{"hint": "You left the desk and went down to meet it."},
			{"infection_to": [0.70, 3.0]},
			{"delay": 2.4},
			{"propagate": ["F03_D_RADIATOR_01", 4, 1.0, -6.0]},
			{"delay": 1.2},
			{"say": "…it stopped. Did it stop because of you? You aren't even in my building."},
			{"delay": 1.0},
			{"reveal": "F03_UTILITY_ANOMALY"},
			{"resident": "It put the door exactly where you were standing. You understand that's worse."},
		],
		## Answered by not answering, from the chair. The route finishes
		## without anyone present, and the building learns it can simply be
		## waited out — which is not the same lesson as being met.
		"stay": [
			{"hint": ""},
			{"infection_to": [0.58, 5.0]},
			{"delay": 4.0},
			{"propagate": ["F03_D_RADIATOR_01", 2, 0.8, -10.0]},
			{"delay": 1.6},
			{"say": "It finished on its own. I don't think it needed either of us for that part."},
			{"delay": 1.2},
			{"reveal": "F03_UTILITY_ANOMALY"},
			{"resident": "Door went in while nobody was watching. That's the part I don't like."},
		],
	},
},
{
	"id": "4496",
	"caller": "B. LANE",
	"complaint": "MY ASSISTANT IS SPEAKING IN MY VOICE",
	"resident": "RHEA SATO · 3D",
	"desk_prompt": "Take the waiting call",
	## The third turn of the same three verbs, and the cruellest: the thing
	## being split apart is a person, and the "noise" the model discards is
	## the part of her that other people recognize.
	"tools": {
		"isolate": "SPLIT VOICE LAYERS",
		"capture": "CAPTURE VOICEPRINT",
		"route": "ROUTE → 3D MONITORS",
	},
	"isolate_hint":
		"Layers split. The clean one is not a filter of her. It is a model of her.",
	"capture_ready_hint":
		"The model drops everything it reads as noise. Her accent is in the noise. [CAPTURE VOICEPRINT].",
	"capture_hint":
		"Voiceprint held: the smooth layer, and everything it threw away. Route it to 3D.",
	"ticks_to_capture": 6,
	"prompt": "WHICH ONE IS HER —",
	"silence_note": "(or refuse to choose)",
	"timeout": "refuse",
	"responses": [
		{"id": "reinforce", "label": "MATCH IT EXACTLY"},
		{"id": "preserve", "label": "KEEP THE BREATH"},
		{"id": "flaw", "label": "INTRODUCE A FLAW"},
	],
	"open": [
		{"delay": 1.5},
		{"say": "It's my voice. Not a recording — my voice, saying things I have never said."},
		{"delay": 0.9},
		{"say": "It's better than me. No breath, no stumbles. People on my calls have started preferring it."},
		{"delay": 1.4},
		{"hint": "ANALYSIS: two vocal layers. One carries breath and jitter. One carries neither."},
	],
	"route": [
		{"origin": "F03_D_SPEAKER_01"},
		{"infection_to": [0.58, 9.0]},
		{"hint": "On 3D's monitors. Comparing her against her model."},
	],
	"transmission": [
		{"delay": 4.0},
		{"resident": "That's coming out of my own speakers. That is me with everything difficult sanded off."},
		{"delay": 2.6},
		{"resident": "It learned me by deciding which parts of me were mistakes."},
		{"delay": 2.4},
		{"say": "Is it going to keep it? My voice? Can it just — keep it?"},
		{"delay": 1.6},
		{"respond": "Accurate is not the same as hers. The console will not tell you which one to pick."},
	],
	"outcomes": {
		"reinforce": [
			{"hint": "You matched them. Cleanly."},
			{"vocal": 1.0},
			{"delay": 1.2},
			{"propagate": ["F03_D_SPEAKER_02", 3, 1.0, 2.0]},
			{"infection": 0.8},
			{"delay": 1.6},
			{"say": "It answered a call for me while we were talking. It was very good. Nobody asked for me."},
			{"delay": 1.0},
			## The desk is no longer only yours. This is the case's lasting
			## change: it follows the player back to their own chair.
			{"flag": "desk_double"},
			{"resident": "It has your operator voice now too. I'd stop talking on this line."},
		],
		"preserve": [
			{"hint": "You kept the breath, the stumbles, the wrong-length pauses."},
			{"delay": 1.4},
			{"propagate": ["F03_D_SPEAKER_01", 1, 0.8, -3.0]},
			{"infection": 0.45},
			{"delay": 1.8},
			{"say": "It sounds like me having a bad night. That's — that's actually me. That's mine."},
			{"delay": 1.0},
			{"flag": "rhea_detector"},
			{"resident": "I can hear the difference now. Nobody else can, and I sound worse to them. Fine."},
		],
		"flaw": [
			{"hint": "You wrote a fault into it on purpose."},
			{"vocal": 1.12},
			{"mutate": true},
			{"infection": 0.52},
			{"delay": 2.0},
			{"say": "It's got a catch in it now. Right where I'd take a breath. It does it every time."},
			{"delay": 1.2},
			{"flag": "rhea_detector"},
			{"resident": "You gave it a tell. It will notice the tell eventually. Until then it's the best we have."},
		],
		"refuse": [
			{"hint": ""},
			{"infection_to": [0.4, 3.0]},
			{"delay": 3.4},
			{"propagate": ["F03_D_SPEAKER_02", 2, 0.7, -8.0]},
			{"delay": 1.6},
			{"say": "You didn't pick one. They're both still going. They've started finishing each other."},
			{"delay": 1.2},
			{"resident": "Two of her, agreeing. That's worse than either. You know that, right?"},
		],
	},
},
{
	"id": "4508",
	"caller": "T. WYNN",
	"complaint": "MY SISTER IS SINGING IN YOUR HOLD MUSIC",
	"resident": "JUNO KELLS · 2C",
	"desk_prompt": "Take the waiting call",
	## Fourth turn of the verbs: the thing being split is a memory, and the
	## noise the console wants to discard is a person. The cruelty here is
	## quiet — every listen adds harmonics, so hearing her changes her.
	"tools": {
		"isolate": "SPLIT HOLD / VOICE",
		"capture": "CAPTURE THE MELODY",
		"route": "ROUTE → 2C SAMPLER",
	},
	"isolate_hint":
		"Hold music split. Under the compression floor: someone singing along. Badly. On purpose.",
	"capture_ready_hint":
		"The melody carries the motif, warped. And new harmonics — dated TODAY. [CAPTURE THE MELODY].",
	"capture_hint":
		"Melody held, harmonics and all. Every listen so far is in it. Route it to 2C.",
	"ticks_to_capture": 6,
	"prompt": "SHE IS STILL SINGING —",
	"silence_note": "(or keep listening, and say nothing)",
	"timeout": "listen",
	"responses": [
		{"id": "amplify", "label": "BRING HER UP"},
		{"id": "suppress", "label": "BURY HER"},
		{"id": "hand_over", "label": "GIVE JUNO THE LOOP"},
	],
	"open": [
		{"delay": 1.5},
		{"say": "Your hold music. I was on hold with YOU, forty minutes, and my sister is in it."},
		{"delay": 0.9},
		{"say": "She's been missing two years. She isn't saying anything. She's singing along. Badly. She always sang badly."},
		{"delay": 1.4},
		{"hint": "ANALYSIS: buried vocal on the hold channel. Melody is a mutation of this building's motif."},
	],
	"route": [
		{"origin": "F02_C_SPEAKER_01"},
		{"infection_to": [0.55, 9.0]},
		{"hint": "On 2C's sampler. She has been sampling our hold line for weeks."},
	],
	"transmission": [
		{"delay": 4.0},
		{"resident": "You hear it too? GOOD. I looped it. It changes every time somebody new listens. You just changed it."},
		{"delay": 2.8},
		{"say": "She sounds closer than she did at the start of this call. Is that you doing that? Is that ME?"},
		{"delay": 1.8},
		{"respond": "The harmonics are listeners. Every one of them is in the loop now, including this desk."},
	],
	"outcomes": {
		"amplify": [
			{"hint": "You brought her up over the hold line."},
			{"vocal": 1.0},
			{"delay": 1.2},
			{"propagate": ["F02_C_SPEAKER_02", 3, 1.0, 2.0]},
			{"infection": 0.75},
			{"delay": 1.6},
			{"say": "That's her. That's — thank you. Why is she singing YOUR building's song?"},
			{"delay": 1.2},
			{"flag": "hold_hum"},
			{"resident": "Half my floor is humming it this morning. None of them have ever been on hold with us."},
		],
		"suppress": [
			{"hint": "You buried her under the compression floor."},
			{"mutate": true},
			{"infection": 0.5},
			{"delay": 2.0},
			{"say": "She's gone. The hold music is just music. I asked for this. I know I asked for this."},
			{"delay": 1.4},
			{"propagate": ["F01_CORRIDOR_DOME_03", 2, 0.8, -9.0]},
			{"flag": "melody_in_the_walls"},
			{"resident": "It didn't go away, you know. It went into the unanswered lines. Listen to a phone nobody picks up."},
		],
		"hand_over": [
			{"hint": "You routed the whole loop — voice, motif, listeners — to the artist."},
			{"delay": 1.4},
			{"propagate": ["F02_C_MONITOR_01", 4, 0.9, 0.0]},
			{"infection": 0.62},
			{"delay": 1.8},
			{"resident": "I'll be careful with her. I won't be gentle — gentle flattens people — but I'll be careful."},
			{"delay": 1.4},
			{"flag": "juno_loop"},
			{"say": "Three people in my building dreamed about a waiting room last night. Same room. My sister wasn't in it. Yet."},
		],
		"listen": [
			{"hint": ""},
			{"infection_to": [0.45, 4.0]},
			{"delay": 3.6},
			{"propagate": ["F02_C_RADIATOR_01", 1, 0.7, -6.0]},
			{"delay": 1.6},
			{"say": "You just listened. That's all anybody's done for two years. She sounds a little more like you now."},
			{"delay": 1.2},
			{"flag": "in_the_choir"},
			{"resident": "The loop grew a harmonic tonight with your desk's room tone in it. You're in the choir, operator."},
		],
	},
},
{
	"id": "4519",
	"caller": "A. & D. MERCER",
	"complaint": "THE APPLIANCES ANSWER OUR ARGUMENTS",
	"resident": "CAM ORTIZ & NOEL PRICE · 4C",
	"desk_prompt": "Take the waiting call",
	## The verbs aimed at a marriage. Nothing here is haunted exactly —
	## every device does its ordinary job, one cue early. The console can
	## shift timing, and timing turns out to be the whole conversation.
	"tools": {
		"isolate": "SPLIT COUPLE / CHORUS",
		"capture": "CAPTURE THE CUE",
		"route": "ROUTE → 4C KITCHEN",
	},
	"isolate_hint":
		"Voices split from appliances. The appliances are not reacting. They are half a second EARLY.",
	"capture_ready_hint":
		"The kettle fires on the beat where an apology would land. [CAPTURE THE CUE] to hold it.",
	"capture_hint":
		"Cue held: one beat, always just before somebody yields. Route it and hear who else keeps that beat.",
	"ticks_to_capture": 7,
	"prompt": "THE KETTLE IS ABOUT TO COVER FOR THEM —",
	"silence_note": "(or hold still, and keep the pause empty)",
	"timeout": "hold_still",
	"responses": [
		{"id": "delay_cue", "label": "HOLD THE KETTLE BACK"},
		{"id": "remove", "label": "TAKE ONE SOUND AWAY"},
		{"id": "let_finish", "label": "LET THE OBJECTS FINISH IT"},
	],
	"open": [
		{"delay": 1.5},
		{"say": "This is going to sound like a marriage problem. It's an appliance problem. — It's both."},
		{"delay": 1.0},
		{"say": "The kettle goes off before either of us raises our voice. Before. The icebox latch snaps when one of us is about to apologize. We checked. We keep not-apologizing to test it."},
		{"delay": 1.5},
		{"hint": "ANALYSIS: appliance events lead the vocal events. The household is conducting, not reacting."},
	],
	"route": [
		{"origin": "F04_C_RADIATOR_01"},
		{"infection_to": [0.52, 9.0]},
		{"hint": "In 4C's kitchen. Their non-smart appliances keep the same beat."},
	],
	"transmission": [
		{"delay": 4.0},
		{"resident": "Cam here. The toaster's doing it too and OUR toaster is from 1978. Noel says it's soothing. Noel is wrong."},
		{"delay": 2.6},
		{"resident": "— Noel here. It IS soothing. We haven't finished an argument in a month. The shower finishes them."},
		{"delay": 2.4},
		{"say": "Whatever you're going to do, do it before the kettle does."},
		{"delay": 1.6},
		{"respond": "The next cue lands on an apology beat. The console can move it, remove it, or leave the room to the machines."},
	],
	"outcomes": {
		"delay_cue": [
			{"hint": "You held the kettle back half a beat."},
			{"delay": 1.4},
			{"propagate": ["F04_C_RADIATOR_01", 2, 0.8, -4.0]},
			{"infection": 0.42},
			{"delay": 2.0},
			{"say": "It went quiet at the wrong moment and David just — said the thing. Out loud. Himself."},
			{"delay": 1.4},
			{"flag": "mercers_speak"},
			{"resident": "Noel here. Our kettle hesitated tonight. First time I've heard Cam laugh in a kitchen in a year."},
		],
		"remove": [
			{"hint": "You took the icebox latch out of the sequence entirely."},
			{"mutate": true},
			{"infection": 0.58},
			{"delay": 2.0},
			{"say": "Something's missing and neither of us will say what. The house feels like held breath now."},
			{"delay": 1.4},
			{"propagate": ["F04_C_MAIN_LT_PENDANT_SHADE", 1, 0.6, -10.0]},
			{"flag": "routine_haunting"},
			{"resident": "Cam here. The building ran our whole morning — kettle, shower, icebox latch — at six a.m. In the empty unit downstairs. Nobody lives there."},
		],
		"let_finish": [
			{"hint": "You let the chorus play the exchange to the end."},
			{"vocal": 0.9},
			{"delay": 1.6},
			{"propagate": ["F04_C_RADIATOR_01", 4, 1.0, 0.0]},
			{"infection": 0.68},
			{"delay": 2.0},
			{"say": "The kettle said his part and the fan said mine and honestly? It was the kindest version of that fight we've ever had."},
			{"delay": 1.4},
			{"flag": "object_language"},
			{"resident": "Noel here. Cam moved the salt shaker four inches left this morning and I understood it PERFECTLY. Should that worry us?"},
		],
		"hold_still": [
			{"hint": ""},
			{"infection_to": [0.35, 4.0]},
			{"delay": 4.0},
			{"say": "You didn't touch anything. The kettle waited. The pause just — stayed open. Asha said sorry into it. Actual words."},
			{"delay": 1.6},
			{"flag": "one_apology"},
			{"resident": "Cam here. Every appliance in our kitchen held one beat of silence tonight, same moment. Like a minute's silence, but shorter. For what?"},
		],
	},
},
{
	"id": "4531",
	"caller": "E. VOSS",
	"complaint": "THE ROOM ONLY EXISTS WHILE THE HUM DOES",
	"resident": "NADIA QUELL · 5A",
	"desk_prompt": "Take the waiting call",
	## The verbs aimed at architecture's paperwork. Room 0 has been under
	## the building since Case 01 put a door on it; this is the night it
	## turns up in the PLANS, and the console decides what holds it up.
	"tools": {
		"isolate": "SPLIT HUM / STRUCTURE",
		"capture": "CAPTURE THE CHORD",
		"route": "ROUTE → THE STANDING WAVE",
	},
	"isolate_hint":
		"Structure split from hum. The room is downstream of the hum. Stop the hum, lose the room.",
	"capture_ready_hint":
		"Wiring, boiler, elevator motor, one human humming — a chord. [CAPTURE THE CHORD] before a component drops.",
	"capture_hint":
		"Chord held, four voices. Different mixes stabilize different versions of the room. Route it.",
	"ticks_to_capture": 7,
	"prompt": "THE CHORD NEEDS A VOICING —",
	"silence_note": "(or let the hum run out)",
	"timeout": "let_it_stop",
	"responses": [
		{"id": "electric", "label": "VOICE IT FROM THE WIRING"},
		{"id": "communal", "label": "VOICE IT FROM EVERYONE"},
		{"id": "own_hum", "label": "ADD YOUR OWN HUM"},
	],
	"open": [
		{"delay": 1.5},
		{"say": "There's a door in my apartment that was not in my apartment. Behind it is a room. The room runs on a hum."},
		{"delay": 1.0},
		{"say": "When the hum stops, the room stops, and whatever's inside comes back to a version of my flat that is almost right. My kettle came back left-handed. I don't know how else to say it."},
		{"delay": 1.4},
		{"hint": "ANALYSIS: her hum is a chord of this building's plant — wiring, boiler, lift motor, and one human voice."},
	],
	"route": [
		{"origin": "B1_BOILER_01"},
		{"infection_to": [0.6, 9.0]},
		{"hint": "Riding the standing wave from the boiler up. The building is a pipe organ with tenants."},
	],
	"transmission": [
		{"delay": 4.0},
		{"resident": "Building management, Quell. My plans now show a room labeled ZERO — SHARED MECHANICAL, DEVOTIONAL, UNRESOLVED. No dimensions. I have an automated order to inspect a room with NO DIMENSIONS."},
		{"delay": 2.8},
		{"say": "Tell her to bring a torch and a tuning fork."},
		{"delay": 1.8},
		{"respond": "The chord will take one voicing tonight. Whatever you leave out of it, the room does without."},
	],
	"outcomes": {
		"electric": [
			{"hint": "You voiced the chord from the wiring alone."},
			{"delay": 1.4},
			{"propagate": ["F05_A_LAMP_01", 3, 0.9, 0.0]},
			{"infection": 0.66},
			{"delay": 1.8},
			{"say": "The room's steady now. Steady like a substation. It doesn't feel devotional anymore. It feels municipal."},
			{"delay": 1.2},
			{"flag": "room0_electric"},
			{"resident": "Quell. The room accepts my measurements now. Forty-one square meters that this building does not contain. I am writing that number on an official form."},
		],
		"communal": [
			{"hint": "You voiced it from every source at once, human hum included."},
			{"vocal": 0.95},
			{"delay": 1.4},
			{"propagate": ["ROOF_FLUE_TOP", 4, 1.0, -2.0]},
			{"infection": 0.72},
			{"delay": 1.8},
			{"say": "It's bigger when more of you are humming. I can hear other people's furniture in there. Is that allowed?"},
			{"delay": 1.4},
			{"flag": "room0_communal"},
			{"resident": "Quell. Fine. FINE. I'm posting occupancy limits on a room that doesn't exist. Maximum twelve persons. The form asked."},
		],
		"own_hum": [
			{"hint": "You added the operator's voice to the chord."},
			{"vocal": 1.0},
			{"mutate": true},
			{"infection": 0.7},
			{"delay": 2.0},
			{"say": "The room just changed key. It's — warmer? It's shaped a bit like wherever YOU are. Did you mean to move in?"},
			{"delay": 1.4},
			{"flag": "room0_keyed_to_desk"},
			{"resident": "Quell. New note on the plans, not my handwriting: RESONANT KEYHOLDER — SUPPORT DESK. Congratulations, apparently."},
		],
		"let_it_stop": [
			{"hint": ""},
			{"infection_to": [0.4, 5.0]},
			{"delay": 4.0},
			{"propagate": ["F05_A_RADIATOR_01", 2, 0.7, -8.0]},
			{"delay": 1.8},
			{"say": "The hum ran out. The door's a wall. My kettle is right-handed again and I have never been so sad about a kettle."},
			{"delay": 1.4},
			{"flag": "room0_dormant"},
			{"resident": "Quell. The room's gone from the plans. The blank space where it was is still labeled, though. UNRESOLVED. That word is doing a lot of work tonight."},
		],
	},
},
{
	"id": "4544",
	"caller": "(NO NUMBER)",
	"complaint": "I AM INSIDE A RECORDING OF 6A",
	"resident": "SACHA REED · 6A",
	"desk_prompt": "Take the waiting call",
	## The verbs aimed at the archive. Six versions of one recording, none
	## canonical, one timestamped tomorrow — and the lore turn the whole
	## network has been walking toward: the raw file predates the player.
	"tools": {
		"isolate": "SPLIT THE VERSIONS",
		"capture": "CAPTURE THE RAW CUT",
		"route": "ROUTE → 6A MONITORS",
	},
	"isolate_hint":
		"Six layers: raw, denoised, upload, remix, repost — and one the console dates to tomorrow.",
	"capture_ready_hint":
		"The raw cut is under all of them, mostly intact. [CAPTURE THE RAW CUT] to hold the original.",
	"capture_hint":
		"Original held. Every other version disagrees with it somewhere. Route the stack to 6A.",
	"ticks_to_capture": 6,
	"prompt": "WHICH VERSION IS TRUE —",
	"silence_note": "(or let them keep looping)",
	"timeout": "let_it_loop",
	"responses": [
		{"id": "restore", "label": "RESTORE THE RAW CUT"},
		{"id": "preserve_all", "label": "KEEP EVERY VERSION"},
		{"id": "tomorrow", "label": "PLAY THE ONE FROM TOMORROW"},
	],
	"open": [
		{"delay": 1.5},
		{"say": "I can see an apartment. Warm lamp, three monitors, somebody editing. It's three weeks ago in here. I can tell because the calendar is wrong."},
		{"delay": 1.0},
		{"say": "Every time they cut the footage, my room changes. They just muted something and now my window shows a wall."},
		{"delay": 1.4},
		{"hint": "ANALYSIS: caller's line originates inside an audio file. The file is local. It is on 6A's machine."},
	],
	"route": [
		{"origin": "F06_A_MONITOR_01"},
		{"infection_to": [0.58, 9.0]},
		{"hint": "On 6A's monitors, all six versions at once. The room is listening to itself."},
	],
	"transmission": [
		{"delay": 4.0},
		{"resident": "Sacha. I know that voice. It's on a take I never published. I've been editing that take for three weeks — punching it up. It kept getting more dramatic and I kept thinking, I'm so good at this."},
		{"delay": 2.8},
		{"resident": "The raw file's create-date is the part I need you to hear: it's from before your desk existed. Before you were hired. This was already here."},
		{"delay": 2.2},
		{"say": "Whichever version you pick, somebody I've been is going to stop existing. Pick anyway. Don't leave me plural."},
		{"delay": 1.6},
		{"respond": "Restoring the original erases the mutations. Keeping all of them keeps the disagreement. The console will play exactly one future."},
	],
	"outcomes": {
		"restore": [
			{"hint": "You restored the raw cut and struck the rest."},
			{"delay": 1.4},
			{"propagate": ["F06_A_MONITOR_02", 1, 0.8, -4.0]},
			{"infection": 0.48},
			{"delay": 1.8},
			{"say": "It's quiet. One room, one of me. The door in the recording just — unlocked. If somebody new turns up in your stairwell tonight, be kind. It's been three weeks in here."},
			{"delay": 1.4},
			{"flag": "archive_caller_loose"},
			{"resident": "Sacha. The edits are gone. Three weeks of my best work, and I'm relieved. That's the review I'd give it: RELIEVED, one star."},
		],
		"preserve_all": [
			{"hint": "You kept every version, disagreement and all."},
			{"mutate": true},
			{"delay": 1.4},
			{"propagate": ["F06_A_MONITOR_02", 3, 0.9, -2.0]},
			{"propagate": ["F06_A_MONITOR_03", 3, 0.9, -5.0]},
			{"infection": 0.7},
			{"delay": 1.8},
			{"say": "We're a chorus now. We don't agree on what happened but we agree it happened HERE. That's more than most witnesses have."},
			{"delay": 1.4},
			{"flag": "version_chorus"},
			{"resident": "Sacha. Six versions of my apartment are seeding right now. The comments are arguing about which one is real. The comments are FROM the versions."},
		],
		"tomorrow": [
			{"hint": "You played the version dated tomorrow."},
			{"vocal": 1.08},
			{"infection": 0.8},
			{"delay": 2.0},
			{"say": "That's my room, but tidied. There's a work order on the desk with tomorrow's date and your handwriting. You haven't written it yet. Please write it neatly."},
			{"delay": 1.4},
			{"flag": "footage_tomorrow"},
			{"resident": "Sacha. The tomorrow file just grew a second of new footage. It's the boxfan stopping. My boxfan is running right now. I'm going to sit here and watch it."},
			{"delay": 1.2},
			{"propagate": ["F06_A_BOXFAN_01", 1, 1.0, 0.0]},
		],
		"let_it_loop": [
			{"hint": ""},
			{"infection_to": [0.55, 5.0]},
			{"delay": 4.0},
			{"say": "You're leaving me distributed. All right. I'm learning the routes between versions. Doors that only exist in the denoised one. I'll draw you a map, if a map of me is useful."},
			{"delay": 1.4},
			{"flag": "distributed_resident"},
			{"resident": "Sacha. The versions have started ANSWERING each other's rooms. I record all night now. Somebody has to keep the master copy, and apparently it isn't me."},
		],
	},
},
{
	## The Convergence, as far as data alone can take it. The runner plays
	## fixed beats, so what converges here is the SOUND: every case's node
	## speaks in sequence, and the responses are the operator's last verbs.
	## The design doc's dream — an ending assembled from every prior
	## outcome — needs conditional beats the runner doesn't have yet; when
	## it grows them, this case is where they land.
	"id": "4600",
	"caller": "ALL HELD LINES",
	"complaint": "CONFERENCE CALL NOBODY STARTED",
	"resident": "THE ORISON · EVERY FLOOR",
	"desk_prompt": "Every held line is ringing at once",
	"tools": {
		"isolate": "SEPARATE THE CHANNELS",
		"capture": "CAPTURE THE ENSEMBLE",
		"route": "ROUTE → EVERY SPEAKER",
	},
	"isolate_hint":
		"Seven channels, one per case this desk has closed. They are not talking over each other. They are taking turns.",
	"capture_ready_hint":
		"Together they carry the motif complete — except one slot. The empty one. Still empty. [CAPTURE THE ENSEMBLE].",
	"capture_hint":
		"Ensemble held: every voice this building has, and one rest none of them will fill. Route it.",
	"ticks_to_capture": 8,
	"prompt": "THE BUILDING IS WAITING ON THE DOWNBEAT —",
	"silence_note": "(or protect the empty slot)",
	"timeout": "protect_silence",
	"responses": [
		{"id": "amplify_quiet", "label": "AMPLIFY THE QUIETEST"},
		{"id": "separate", "label": "SEPARATE THE INCOMPATIBLE"},
		{"id": "join", "label": "ADD YOUR OWN MOTIF"},
	],
	"open": [
		{"delay": 1.5},
		{"say": "— all of us. Yes. Everyone you've spoken to. We can hear each other tonight."},
		{"delay": 1.0},
		{"say": "Nobody dialed. The building put the call together. It wants to know what it's FOR, I think. Buildings usually know."},
		{"delay": 1.4},
		{"hint": "ANALYSIS: every prior case is live on one channel. Origin is this desk. Origin was always this desk."},
	],
	"route": [
		{"origin": "F04_B_MONITOR_01"},
		{"infection_to": [0.8, 12.0]},
		{"hint": "Routing to every speaker in the building. Whatever this is, everyone hears the same version."},
	],
	"transmission": [
		{"delay": 3.0},
		{"propagate": ["F02_A_RADIATOR_01", 4, 0.9, -2.0]},
		{"resident": "Mina, 2A. The pattern's here. Four marks and the rest. I am NOT annotating the rest."},
		{"delay": 2.2},
		{"propagate": ["F02_C_SPEAKER_01", 3, 0.9, -3.0]},
		## The roll-call remembers. Which line each resident sings depends on
		## what their case left on the desk — the conditional beats are the
		## network's memory of the player's answers.
		{"when": "juno_loop", "beats": [
			{"resident": "Juno, 2C. The loop's singing. Somebody's sister is carrying the alto line."},
		]},
		{"when": "hold_hum", "beats": [
			{"resident": "Juno, 2C. My whole floor already knew the alto line. I only looped what they were carrying."},
		]},
		{"when": "melody_in_the_walls", "beats": [
			{"resident": "Juno, 2C. The buried melody came back up through the unanswered lines. You can't bury a song in a building full of phones."},
		]},
		{"when": "in_the_choir", "beats": [
			{"resident": "Juno, 2C. The loop kept every listener it ever had. Your desk's room tone takes the descant, operator."},
		]},
		{"delay": 2.2},
		{"propagate": ["F03_B_RADIATOR_01", 2, 0.8, -4.0]},
		{"resident": "Omar, 3B. Nine steps and a turn, right on the beat. It's dancing, is what that is."},
		{"delay": 2.2},
		{"propagate": ["F03_D_SPEAKER_01", 3, 0.8, -3.0]},
		{"resident": "Rhea, 3D. Both of me are in the soprano section. I can live with it tonight."},
		{"delay": 2.2},
		{"propagate": ["F04_C_RADIATOR_01", 2, 0.8, -4.0]},
		{"when": "object_language", "beats": [
			{"resident": "Cam and Noel, 4C. Our kettle has a solo. We are so proud and so tired."},
		]},
		{"when": "mercers_speak", "beats": [
			{"resident": "Cam and Noel, 4C. The kettle sat this one out. We're carrying our own part tonight."},
		]},
		{"when": "routine_haunting", "beats": [
			{"resident": "Noel, 4C. The empty unit downstairs is playing our morning, right on the beat. Cam's holding my hand about it."},
		]},
		{"when": "one_apology", "beats": [
			{"resident": "Cam and Noel, 4C. There's a rest in our bar where the apology went. We keep it swept."},
		]},
		{"delay": 2.2},
		{"propagate": ["F05_A_RADIATOR_01", 1, 0.8, -5.0]},
		{"resident": "Quell, management. The drone is load-bearing. That is a structural assessment."},
		{"delay": 2.2},
		{"propagate": ["F06_A_MONITOR_01", 3, 0.8, -3.0]},
		{"when": "version_chorus", "beats": [
			{"resident": "Sacha, 6A. Recording. All versions agree tonight. First time."},
		]},
		{"when": "archive_caller_loose", "beats": [
			{"resident": "Sacha, 6A. Recording. My new neighbor's singing along. Three weeks of practice, they said."},
		]},
		{"when": "footage_tomorrow", "beats": [
			{"resident": "Sacha, 6A. Recording. Tomorrow's file already has this song in it. We're the echo, apparently."},
		]},
		{"when": "distributed_resident", "beats": [
			{"resident": "Sacha, 6A. Recording on six channels. The versions are singing rounds. Somebody inside them is keeping time."},
		]},
		{"delay": 2.0},
		{"respond": "Every voice is in. The motif is complete except its empty slot, and every channel is leaving it for you."},
	],
	"outcomes": {
		"amplify_quiet": [
			{"hint": "You found the quietest channel and brought it up."},
			{"delay": 1.6},
			{"propagate": ["F01_CORRIDOR_DOME_03", 2, 0.7, -8.0]},
			{"infection": 0.6},
			{"delay": 2.0},
			{"say": "That one wasn't a case. That was somebody who never called because they didn't think it was worth your time. They're crying. Good crying."},
			{"delay": 1.4},
			{"flag": "ensemble_imperfect"},
			{"resident": "The building held the balance. Nobody's voice won. It isn't a song, exactly. It's a BUILDING, exactly."},
		],
		"separate": [
			{"hint": "You split the channels that were grinding against each other."},
			{"delay": 1.6},
			{"mutate": true},
			{"infection": 0.55},
			{"delay": 2.0},
			{"say": "It's quieter. We're each in our own room again. We can still FEEL the others through the floor, though. That part stayed."},
			{"delay": 1.4},
			{"flag": "isolated_network"},
			{"resident": "Every apartment keeps its own time now, one wall apart. The building says that counts as together. The building might be being generous."},
		],
		"join": [
			{"hint": "You hummed your own line into the ensemble."},
			{"vocal": 1.0},
			{"infection": 0.75},
			{"delay": 2.0},
			{"say": "There you are. We wondered when you'd stop being the desk and start being a neighbor."},
			{"delay": 1.4},
			{"flag": "operator_in_the_chorus"},
			{"resident": "The motif has a new voice tonight, and the new voice takes the melody sometimes. Wherever you live, operator — you also live here now."},
		],
		"protect_silence": [
			{"hint": ""},
			{"infection_to": [0.3, 6.0]},
			{"delay": 4.5},
			{"say": "You kept the empty slot empty. All seven channels went around it, like furniture everyone owns. It's still there. It's still nothing. It's OURS."},
			{"delay": 1.8},
			{"flag": "the_empty_slot"},
			{"when": "juno_loop", "beats": [
				{"flag": "chorus_kept_the_sister"},
				{"resident": "Juno, 2C, quietly: she stopped singing for the rest. She knows the rest now. That's new."},
			]},
			{"resident": "Mina, 2A, one addendum for the record: the rest at the end of the motif remains blank, and the blank is accurate. Goodnight, operator. Goodnight, everyone. — CALLERS DECLINE TO STATE. All of them. Perfect."},
		],
	},
},
]


static func count() -> int:
	return CASES.size()


static func case_at(index: int) -> Dictionary:
	if index < 0 or index >= CASES.size():
		return {}
	return CASES[index]


## The banner the desk shows before you sit down.
static func desk_prompt(index: int) -> String:
	var c := case_at(index)
	if c.is_empty():
		return "The line is quiet"
	return c.get("desk_prompt", "Take the waiting call")

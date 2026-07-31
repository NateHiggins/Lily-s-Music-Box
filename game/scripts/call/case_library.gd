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
	"silence_note": "(or wait at the end of it)",
	"timeout": "wait",
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
		{"respond": "The route ends in a stretch of your corridor that is longer than the building is wide."},
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
		"wait": [
			{"hint": "You stayed where it ended."},
			{"infection_to": [0.66, 4.0]},
			{"delay": 3.2},
			{"propagate": ["F03_D_RADIATOR_01", 4, 1.0, -6.0]},
			{"delay": 1.4},
			{"say": "…it walked up to where you are and stopped. You didn't move. It liked that."},
			{"delay": 1.0},
			{"reveal": "F03_UTILITY_ANOMALY"},
			{"resident": "It put a door where you were standing. I'd rather you'd moved."},
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

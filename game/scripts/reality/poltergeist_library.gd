class_name PoltergeistLibrary
## One poltergeist per resident, and not one of them is a ghost.
##
## Every personality here is derived from that resident's case in
## `reality_cases.json` — its manifestation, its resolution flags, its portal
## rule. Nothing is invented. Mina's case says captions escalate from nouns
## to false claims about thoughts; so her poltergeist annotates, and what it
## eventually annotates is the player. Omar's says every repaired object
## returns with another impossible fault; so his breaks what you have just
## seen working. The haunting IS the wound, restated until it is legible.
##
## That is the design rule, and it is what separates this from a jump-scare
## generator: an intrusion is only allowed if it is a sentence about the
## person whose apartment it happens in. The escalation ladder is the
## argument being made more plainly each time —
##
##   tell      an anomaly small enough to be dismissed
##   pattern   the same anomaly, repeating, no longer dismissible
##   reenact   the trauma staged in the room, using the room
##   address   it stops performing and speaks to the player directly
##
## The address rung is the point of the whole system. It is where the
## haunting says the thing the resident cannot, and it is deliberately the
## rarest — a poltergeist that explains itself every ten minutes is a
## chatterbox, not a wound. The director spends a long time on rungs one and
## two so that rung four lands.
##
## An act is [kind, argument]. The executors are in `intrusions.gd`; the
## meta-layer kinds are in `fourth_wall.gd`. Anything an act touches must be
## restorable, because a poltergeist is a state the building passes through,
## not damage it keeps.

const POLTERGEISTS := {
"mina_caption_crisis": {
	"unit": "2A", "resident": "Mina Vale",
	"wound": "Everything she is must be annotated, or it does not count.",
	"tell": [["prop_turn", 1], ["whisper", "…correction. correction."]],
	"pattern": [["caption_room", 3], ["light_flicker", "stutter"]],
	"reenact": [["caption_room", 6], ["prop_turn", 3],
			["whisper", "the record shows you paused here."]],
	"address": [["caption_player", 4]],
	"voice": "[SUBJECT DECLINES TO STATE WHAT HE IS FEELING]",
},
"juno_feedback_tetris": {
	"unit": "2C", "resident": "Juno Kells",
	"wound": "Her work was taken, so she takes, and calls it collaboration.",
	"tell": [["sound", "hum"], ["light_flicker", "beat"]],
	"pattern": [["motif_mutate", 1], ["prop_drift", 2]],
	"reenact": [["sound", "hum"], ["motif_mutate", 2],
			["whisper", "that was my part. that was MY part."]],
	"address": [["fourth_wall", "second_operator"]],
	"voice": "Somebody else is already answering in this channel.",
},
"omar_unrepairable": {
	"unit": "3B", "resident": "Omar Bell",
	"wound": "If he cannot fix it, he failed it. There is no third option.",
	"tell": [["prop_tremble", 2]],
	"pattern": [["prop_fault", 2], ["sound", "knock"]],
	"reenact": [["prop_fault", 4], ["prop_fall", 1],
			["whisper", "i just had that working. i just HAD that working."]],
	"address": [["fourth_wall", "unrepairable_notice"]],
	"voice": "Some things are not repairable. You are allowed to say so.",
},
"rhea_bad_karaoke": {
	"unit": "3D", "resident": "Rhea Sato",
	"wound": "Every involuntary sound she makes is evidence against her.",
	"tell": [["sound", "breath"]],
	"pattern": [["sound", "breath"], ["light_flicker", "swell"]],
	"reenact": [["whisper", "you made a noise. everyone heard it."],
			["sound", "breath"], ["prop_turn", 4]],
	"address": [["fourth_wall", "mic_hot"]],
	"voice": "Your microphone has been open this entire time.",
},
"nadia_code_pinball": {
	"unit": "5A", "resident": "Nadia Quell",
	"wound": "She was made to sign off on something she knew was unsafe.",
	"tell": [["light_flicker", "fault"]],
	"pattern": [["distort", "folded"], ["prop_turn", 2]],
	"reenact": [["distort", "fractured"],
			["whisper", "the egress was compliant on paper."]],
	"address": [["fourth_wall", "violation_notice"]],
	"voice": "OCCUPANCY EXCEEDED. THIS FLOOR HAS NO SECOND EXIT.",
},
"sacha_camera_delay": {
	"unit": "6A", "resident": "Sacha Reed",
	"wound": "Nothing that happened to them counts until it is documented.",
	"tell": [["sound", "shutter"]],
	"pattern": [["prop_turn", 3], ["sound", "shutter"]],
	"reenact": [["fourth_wall", "photo_behind"],
			["whisper", "wait — do that again, i wasn't recording."]],
	"address": [["fourth_wall", "session_time"]],
	"voice": "You have been on the line for %d minutes. Nobody has verified that.",
},
"evelyn_paper_jam": {
	"unit": "1A", "resident": "Evelyn Marsh",
	"wound": "Care and control became the same reflex, and it never switches off.",
	"tell": [["prop_drift", 1]],
	"pattern": [["caption_room", 2], ["prop_turn", 2]],
	"reenact": [["caption_room", 4],
			["whisper", "this is nearly right. do it once more."]],
	"address": [["fourth_wall", "graded"]],
	"voice": "SEE ME.",
},
"teresa_call_bells": {
	"unit": "1D", "resident": "Teresa Vale",
	"wound": "She rested once, and someone died, and the bell never stopped.",
	"tell": [["sound", "bell"]],
	"pattern": [["sound", "bell"], ["light_flicker", "stutter"]],
	"reenact": [["sound", "bell"], ["prop_tremble", 3],
			["whisper", "somebody is calling. it isn't your shift."]],
	"address": [["fourth_wall", "alarm"]],
	"voice": "Not every alarm is yours.",
},
"lena_unraveling": {
	"unit": "2B", "resident": "Lena Ortiz",
	"wound": "She is loved for being useful, so she must never stop mending.",
	"tell": [["prop_drift", 1]],
	"pattern": [["prop_drift", 3], ["light_flicker", "swell"]],
	"reenact": [["prop_scatter", 5],
			["whisper", "if i put it all back, will you stay."]],
	"address": [["fourth_wall", "unravel_ui"]],
	"voice": "A visible repair is still a repair.",
},
"malcolm_memory_plants": {
	"unit": "3A", "resident": "Malcolm Reed",
	"wound": "He kept a cutting alive so the goodbye would not finish.",
	"tell": [["sound", "leaves"]],
	"pattern": [["prop_drift", 2], ["whisper", "…say it again."]],
	"reenact": [["sound", "leaves"], ["light_follow", 1],
			["whisper", "one more time. just the last part."]],
	"address": [["fourth_wall", "replay_last"]],
	"voice": "Compost is transformation. You are allowed to let it finish.",
},
"peter_form_corridor": {
	"unit": "4A", "resident": "Peter Wren",
	"wound": "He was brave once, imperfectly, and has been filing about it since.",
	"tell": [["prop_turn", 1]],
	"pattern": [["distort", "accordion"], ["prop_drift", 2]],
	"reenact": [["distort", "accordion"],
			["whisper", "pending further information. pending. pending."]],
	"address": [["fourth_wall", "consent_form"]],
	"voice": "PROCEEDING WITHOUT COMPLETE INFORMATION — ACKNOWLEDGE",
},
"cam_tilted_room": {
	"unit": "4C", "resident": "Cam Ortiz",
	"wound": "If he stops moving the crash catches up, so he never stops.",
	"tell": [["prop_tremble", 1]],
	"pattern": [["distort", "breathing"], ["prop_drift", 2]],
	"reenact": [["distort", "upside_down"], ["prop_fall", 2],
			["whisper", "don't stand still. please don't stand still."]],
	"address": [["fourth_wall", "stillness"]],
	"voice": "Weight can be shared. You can put it down.",
},
"noel_domestic_museum": {
	"unit": "4C", "resident": "Noel Price",
	"wound": "He preserved his family so carefully that nobody may touch it.",
	"tell": [["prop_turn", 2]],
	"pattern": [["museum_label", 3]],
	"reenact": [["museum_label", 6],
			["whisper", "please do not handle. please do not handle."]],
	"address": [["fourth_wall", "accession"]],
	"voice": "ACCESSION 1927.4C.1 — DOMESTIC LIFE, UNUSED, EXCELLENT CONDITION",
},
"transient_infinite_checkout": {
	"unit": "4D", "resident": "Transient Guests",
	"wound": "Leaving forever is how they avoid ever deciding to leave.",
	"tell": [["prop_drift", 1]],
	"pattern": [["distort", "dollhouse"], ["sound", "knock"]],
	"reenact": [["distort", "dollhouse"], ["prop_vanish", 3],
			["whisper", "checkout is at eleven. checkout is at eleven."]],
	"address": [["fourth_wall", "checkout"]],
	"voice": "YOUR STAY HAS BEEN EXTENDED INDEFINITELY. NO ACTION REQUIRED.",
},
"cal_memory_radio": {
	"unit": "5B", "resident": "Cal Dwyer",
	"wound": "He tuned a moment so finely that it can never be allowed to end.",
	"tell": [["sound", "static"]],
	"pattern": [["sound", "static"], ["light_flicker", "fault"]],
	"reenact": [["sound", "static"], ["motif_mutate", 1],
			["whisper", "hold it there. don't move the dial."]],
	"address": [["fourth_wall", "previous_session"]],
	"voice": "RESUMING PLAYBACK FROM A SESSION THAT HAS NOT HAPPENED",
},
"iris_runaway_paint": {
	"unit": "5C", "resident": "Iris Bell",
	"wound": "An imagined audience holds the brush, and it is never satisfied.",
	"tell": [["light_flicker", "swell"]],
	"pattern": [["prop_turn", 4], ["light_follow", 1]],
	"reenact": [["prop_turn", 6], ["light_follow", 1],
			["whisper", "they're watching you look at it."]],
	"address": [["fourth_wall", "audience"]],
	"voice": "Creation need not perform. Nobody is scoring this.",
},
"jonah_sentence_insects": {
	"unit": "6B", "resident": "Jonah Price",
	"wound": "He cannot write the ending, so the ending has started biting.",
	"tell": [["whisper", "…and then he"]],
	"pattern": [["word_loss", 2], ["sound", "skitter"]],
	"reenact": [["word_loss", 4], ["prop_tremble", 3],
			["whisper", "i never finished the"]],
	"address": [["fourth_wall", "unfinished"]],
	"voice": "Endings do not erase continuation. Write it badly and let it end.",
},
"mae_contradictory_antiques": {
	"unit": "6C", "resident": "Mae Kessler",
	"wound": "Two true versions of her family cannot both be survivable.",
	"tell": [["prop_turn", 1]],
	# Two histories, and an object that is in both and neither: it is gone
	# when you look away and back, which is the shape of her whole problem.
	"pattern": [["museum_label", 2], ["prop_vanish", 2]],
	"reenact": [["museum_label", 4],
			["whisper", "both of those happened. both of them."]],
	"address": [["fourth_wall", "provenance"]],
	"voice": "SAVE ORIGIN DISPUTED — TWO HISTORIES ON FILE — BOTH RETAINED",
},
}


static func ids() -> Array:
	return POLTERGEISTS.keys()


static func profile(case_id: String) -> Dictionary:
	return POLTERGEISTS.get(case_id, {})


## The ladder in order, so the director can index a rung by tier 1-4 without
## caring what any of them contain.
static func rung(case_id: String, tier: int) -> Array:
	var p := profile(case_id)
	if p.is_empty():
		return []
	match clampi(tier, 1, 4):
		1: return p.tell
		2: return p.pattern
		3: return p.reenact
		_: return p.address


static func unit_of(case_id: String) -> String:
	return profile(case_id).get("unit", "")

extends RefCounted
## Deterministic offline conversation. The caller supplies a fresh, read-only
## witnessed context for each turn. Replies never execute gameplay actions.
const Intent = preload("res://scripts/device/companion_intent.gd")
const CalendarContext = preload("res://scripts/device/companion_calendar_context.gd")
const Memory = preload("res://scripts/device/companion_memory.gd")
const LIBRARY := "res://data/dialogue/companion.json"
# Explicit producer requests only; exhaust each small repertoire, then stay quiet.
const EVENT_SEQUENCES := {
	"hesitation":["hesitation_event_1","hesitation_event_2","hesitation_event_3"],
	"exploration":["explore_event_1","explore_event_2","explore_event_3"],
	"revisit":["revisit_event_1","revisit_event_2"],
	"paper_jam":["jam_event_1","jam_event_2"],
	"typing_interrupted":["interruption_event_1","interruption_event_2"],
	"typing_resumed":["resume_event_1","resume_event_2"],
	"story_discovery":["discovery_event_1","discovery_event_2","discovery_event_3","discovery_familiar"]
}
var memory := Memory.new()
var lines: Dictionary = {}
var branches: Dictionary = {}
var followups: Dictionary = {}
var errors: Array[String] = []

func _init() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIBRARY))
	if data is not Dictionary or data.get("schema_version") != 1:
		errors.append("Invalid companion dialogue document")
		return
	if data.get("lines") is not Array or data.get("branches") is not Array:
		errors.append("Invalid companion dialogue collections")
		return
	for record: Variant in data.lines:
		if record is not Dictionary or record.get("id") is not String or record.get("text") is not String:
			errors.append("Invalid line record")
			continue
		var id: String = record.id
		if id.is_empty() or id.length() > 80 or lines.has(id) or record.text.is_empty() or record.text.length() > 2048:
			errors.append("Invalid or duplicate line: " + id)
			continue
		lines[id] = record.text
	for record: Variant in data.branches:
		if record is not Dictionary or record.get("id") is not String or record.get("sequence") is not Array:
			errors.append("Invalid branch record")
			continue
		var id: String = record.id
		if id.is_empty() or id.length() > 80 or branches.has(id) or record.sequence.is_empty():
			errors.append("Invalid or duplicate branch: " + id)
			continue
		branches[id] = record.sequence
		for line_id: Variant in record.sequence:
			if line_id is not String or not lines.has(line_id): errors.append("Missing branch line: " + str(line_id))
		if record.get("followups") is not Array:
			errors.append("Missing branch followups: " + id)
			continue
		followups[id] = record.followups
		for reply: Variant in record.followups:
			if reply is not Dictionary or reply.get("phrases") is not Array or not lines.has(reply.get("line_id", "")):
				errors.append("Invalid followup: " + id)
				continue
			for phrase: Variant in reply.phrases:
				if phrase is not String or phrase.is_empty() or phrase != Intent.normalize(phrase): errors.append("Invalid followup phrase: " + id)

func respond(raw: String, context: Dictionary) -> Dictionary:
	if not errors.is_empty(): return {"text":"The correspondence file cannot be read.", "line_id":"", "intent":"failure"}
	var parsed := Intent.parse(raw)
	var intent: String = parsed.intent
	var text: String = parsed.text
	var id := intent
	var output := ""
	var values: Dictionary = {}
	var visible: Array = context.get("visible", [])
	var matches: Array[Dictionary] = Intent.candidates(text, visible)
	# A fresh command replaces the clarification request. A bare target noun
	# still resolves it against the current visible IDs.
	if intent != "unknown": memory.pending_ids.clear()
	var following := text in ["tell me more", "go on", "why is that", "what do you mean", "and then", "yes"]
	var branch_reply := ""
	for reply: Dictionary in followups.get(memory.branch, []):
		for phrase: String in reply.phrases:
			if text == phrase:
				branch_reply = str(reply.line_id)
				break
		if not branch_reply.is_empty(): break
	if intent == "leave":
		id = "leave"
	elif not branch_reply.is_empty():
		id = branch_reply
	elif following and not memory.branch.is_empty():
		id = _branch_line(memory.branch)
	elif not memory.pending_ids.is_empty():
		# Pending ambiguity never authorizes a vanished or newly substituted object.
		var current: Array[Dictionary] = []
		for object: Dictionary in matches:
			if str(object.id) in memory.pending_ids: current.append(object)
		if current.size() == 1:
			output = _observation(current[0])
			memory.last_object = str(current[0].id)
			memory.pending_ids.clear()
			id = "observation"
		else:
			memory.pending_ids.clear()
			id = "target_gone"
	elif intent in ["alive", "fear", "care", "hesitate", "jam"]:
		memory.branch = intent
		id = _branch_line(intent)
	elif text in ["what is the orison", "what is orison", "tell me about the orison", "tell me about the world"]:
		memory.branch = "world"
		id = _branch_line("world")
	elif Intent.contains_phrase(text, "trust"):
		memory.branch = "trust"
		id = _branch_line("trust")
	elif Intent.contains_phrase(text, "friend"):
		memory.branch = "friend"
		id = _branch_line("friend")
	elif Intent.contains_phrase(text, "vantry"):
		id = "manufacturer"
	elif Intent.contains_phrase(text, "warranty"):
		id = "warranty"
	elif text in ["sorry", "i m sorry", "i am sorry"]:
		id = "sorry"
	else:
		match intent:
			"identity": id = "identity_again" if int(memory.counts.get(intent, 0)) > 0 else "identity"
			"help":
				output = str(context.get("objective", ""))
				id = "help_empty" if output.is_empty() else "objective"
			"inventory":
				var items: Array = context.get("inventory", [])
				var names: PackedStringArray = []
				for item: Variant in items:
					if item is String: names.append(item)
				output = "Carried items: " + ", ".join(names) if not names.is_empty() else ""
				id = "inventory_empty" if output.is_empty() else "inventory_report"
			"remember":
				id = "memory_empty" if memory.history.is_empty() else "remember"
				if not memory.history.is_empty(): values = memory.history.back()
			"look":
				output = str(context.get("location", ""))
				var names: PackedStringArray = []
				for object: Dictionary in visible: names.append(str(object.get("name", "unlabelled object")))
				if not names.is_empty(): output += ("\n" if not output.is_empty() else "") + "In view: " + ", ".join(names)
				id = "look_empty" if output.is_empty() else "look_report"
			"examine", "use", "ask":
				if text in ["examine it", "inspect it", "use it"]:
					for object: Dictionary in visible:
						if str(object.id) == memory.last_object: matches.append(object)
				if matches.size() > 1:
					var names: PackedStringArray = []
					for object: Dictionary in matches:
						memory.pending_ids.append(str(object.id))
						names.append(str(object.name))
					values = {"names":", ".join(names)}
					id = "clarify"
				elif matches.size() == 1:
					memory.last_object = str(matches[0].id)
					values = {"name":str(matches[0].name)}
					id = "action_boundary" if intent == "use" else "observation"
					if intent != "use": output = _observation(matches[0])
				else: id = "action_empty" if intent == "use" else ("why" if intent == "ask" else "examine_empty")
			"navigate":
				# Route text comes from a verified route provider, never the parser.
				var routes: Dictionary = context.get("routes", {})
				for destination: String in routes:
					if Intent.contains_phrase(text, Intent.normalize(destination)):
						output = str(routes[destination])
						break
				id = "navigation_unknown" if output.is_empty() else "route_report"
			"newspaper":
				output = str(context.get("newspaper_report", ""))
				id = "newspaper_unavailable" if output.is_empty() else "newspaper_report"
				if not output.is_empty(): output = _with_comment(output, context.get("newspaper_comment_id", ""))
			"joke": id = "joke_again" if int(memory.counts.get(intent, 0)) > 0 else "joke_request"
			"magic": id = "magic_word"
			"undo": id = "undo_request"
			"sing": id = "sing_request"
			"wait": id = "wait_request"
			"silence": id = "silence_request"
			"rude": id = "rude_command"
			"weather":
				output = str(context.get("weather_report", ""))
				id = "weather_unknown" if output.is_empty() else "weather_report"
				if not output.is_empty(): output = _with_comment(output, context.get("weather_comment_id", ""))
			"eat":
				var count := int(memory.counts.get("eat", 0))
				id = "eat_first" if count == 0 else ("eat_again" if count < 3 else "eat_persistent")
			"unknown": id = "unknown_again" if int(memory.counts.get(intent, 0)) > 0 else "unknown"
	if output.is_empty(): output = str(lines.get(id, lines.get("unknown", "")))
	for key: String in values: output = output.replace("{" + key + "}", str(values[key]))
	# A new topic closes the old conversational branch. A later bare "yes"
	# must not resurrect a question from before an inventory/route/leave turn.
	if not memory.branch.is_empty():
		var belongs: bool = id in branches.get(memory.branch, [])
		for reply: Dictionary in followups.get(memory.branch, []):
			if id == str(reply.line_id): belongs = true
		if not belongs: memory.branch = ""
	memory.record(raw, intent, id, output)
	if intent == "care": memory.trust = mini(100, memory.trust + 1)
	return {"line_id":id, "text":output, "intent":intent, "end_conversation":intent == "leave"}

func event(id: String) -> Dictionary:
	# Event producers must witness the named circumstance, arbitrate protected
	# dialogue/focus/power, and request only after delivery is possible.
	if EVENT_SEQUENCES.has(id):
		for candidate: String in EVENT_SEQUENCES[id]:
			if not bool(memory.seen.get(candidate, false)): return event(candidate)
		return {}
	# Event producers explicitly request a line; there is no random idle chatter.
	if not lines.has(id) or bool(memory.seen.get(id, false)): return {}
	if memory.seen.size() >= 128: return {}
	memory.seen[id] = true
	return {"line_id":id, "text":str(lines[id]), "intent":"event"}

func _branch_line(id: String) -> String:
	var sequence: Array = branches.get(id, [])
	if sequence.is_empty(): return "unknown"
	var count := int(memory.counts.get("branch:" + id, 0))
	memory.increment("branch:" + id)
	return str(sequence[mini(count, sequence.size() - 1)])

func _observation(object: Dictionary) -> String:
	var supplied := str(object.get("observation", ""))
	return supplied if not supplied.is_empty() else str(lines.object_unreported).replace("{name}", str(object.name))

func _with_comment(report: String, value: Variant) -> String:
	# Only approved authored IDs from the dated witness adapter; no new prose.
	if value is not String or not (value.begins_with("weather_comment_") or value.begins_with("news_comment_")):
		return report
	if not lines.has(value) or bool(memory.seen.get(value, false)) or memory.seen.size() >= 128:
		return report
	memory.seen[value] = true
	return report + "\n" + str(lines[value])

## Deliberate conversation entry point for the world/focus adapter. The paper
## selection must come from the active reading surface, never an archive scan.
func respond_calendar(raw: String, context: Dictionary, clock: CampaignClock,
		source: String, conditions: Dictionary, catalog: NewspaperCatalog = null,
		read_issue: Dictionary = {}) -> Dictionary:
	return respond(raw, CalendarContext.enrich(context, clock, source, conditions, catalog, read_issue))

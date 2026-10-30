extends Node
## Offline domain diagnostic; no claim about physical input or world operation.
const Conversation = preload("res://scripts/device/companion_conversation.gd")
const Intent = preload("res://scripts/device/companion_intent.gd")
const Memory = preload("res://scripts/device/companion_memory.gd")
const Provider = preload("res://scripts/device/companion_provider.gd")
var checks: Array[Dictionary] = []

func check(ok: bool, name: String) -> void:
	checks.append({"name":name, "passed":ok})
	if not ok: push_error(name)

func _ready() -> void:
	var dialogue := Conversation.new()
	check(dialogue.errors.is_empty() and dialogue.lines.size() >= 50, "structured library loads at least fifty distinct lines")
	check(Intent.normalize("  WHAT'S...Here?!  ") == "what s here", "case punctuation and spacing normalize")
	check(Intent.parse("Could you look at the brass valve?").intent == "examine", "specific look-at phrase outranks look")
	check(Intent.parse("What am I carrying?").intent == "inventory", "natural inventory phrase")
	check(Intent.parse("please fix the drain").intent == "use", "request recognized without executing it")
	check(Intent.parse("yesterday").intent == "unknown", "verb fragments do not match inside words")
	var context := {"location":"Service hall", "objective":"Inspect the reported radiator.",
		"inventory":["Rubber protectant"], "weather_report":"Rain expected after dusk.",
		"visible":[{"id":"hot", "name":"Hot valve", "aliases":["valve", "hot"], "observation":"The hot valve is open."},
			{"id":"cold", "name":"Cold valve", "aliases":["valve", "cold"], "observation":"The cold valve is closed."}]}
	var original := context.duplicate(true)
	check(dialogue.respond("help", context).text == context.objective, "help uses current objective verbatim")
	check(dialogue.respond("check my bag", context).text.contains("Rubber protectant"), "inventory reads supplied items")
	check(not dialogue.respond("inventory", {}).text.contains("Rubber protectant"), "inventory does not retain stale world facts")
	check(dialogue.respond("forecast", context).text == context.weather_report, "weather uses dated report supplied by owner")
	check(dialogue.respond("examine valve", context).line_id == "clarify", "ambiguous specific parts request clarification")
	check(dialogue.respond("hot", context).text == "The hot valve is open.", "clarification resolves against current visible IDs")
	check(dialogue.respond("inspect it", context).text == "The hot valve is open.", "pronoun resolves last seen object")
	check(Intent.candidates("open hot valve", context.visible).size() == 1, "specific part name outranks shared generic alias")
	dialogue.respond("examine valve", context)
	check(dialogue.respond("where is the vault", context).line_id == "navigation_unknown", "explicit new command interrupts pending clarification")
	dialogue.respond("examine valve", context)
	check(dialogue.respond("hot", {}).line_id == "target_gone", "vanished clarification cannot leak an observation")
	var boundary: Dictionary = dialogue.respond("open hot valve", context)
	check(boundary.line_id == "action_boundary" and not boundary.has("actions") and context == original, "action requests leave all authoritative state unchanged")
	check(dialogue.respond("where is the vault", context).line_id == "navigation_unknown", "no invented route")
	check(dialogue.respond("are you alive", context).line_id == "alive", "long branch starts")
	check(dialogue.respond("tell me more", context).line_id == "alive_follow", "branch follows natural continuation")
	var snapshot: Dictionary = dialogue.memory.snapshot()
	var restored := Conversation.new()
	check(restored.memory.restore(JSON.parse_string(JSON.stringify(snapshot))), "JSON roundtrip restores bounded memory")
	check(restored.respond("are you alive", {}).line_id == "alive_uncertain", "longer branch resumes its next stage through reload")
	check(restored.respond("Does it matter?", {}).line_id == "alive_matters", "specific follow-up takes authored conversational fork")
	for index in 5: restored.respond("eat the machine", {})
	check(restored.respond("eat it", {}).line_id == "eat_persistent", "persistent impossible request acknowledged")
	check(not restored.event("activation").is_empty() and restored.event("activation").is_empty(), "event lines are once per memory")
	for index in Memory.LIMIT + 22: restored.respond("nonsense", {})
	check(restored.memory.history.size() == Memory.LIMIT, "history stays bounded")
	var before: Dictionary = restored.memory.snapshot()
	var invalid := before.duplicate(true)
	invalid.trust = "unlock_everything"
	check(not restored.memory.restore(invalid) and restored.memory.snapshot() == before, "corrupt memory rejection is atomic")
	invalid = before.duplicate(true)
	invalid.counts.bad = INF
	check(not restored.memory.restore(invalid), "nonfinite counters rejected")
	var full := Memory.new()
	for index in 64: full.counts["old:" + str(index)] = 1
	full.record("new question", "new_intent", "unknown", "Reply")
	check(full.counts.size() == 64 and full.history.size() == 1, "full counter table stays bounded without losing correspondence")
	check(not Provider.new().available(), "offline system has no network dependency")
	var ids: Array[String] = ["alive", "alive_follow"]
	check(Provider.valid_selection("alive", ids) and not Provider.valid_selection("invented_unlock", ids), "provider restricted to approved authored IDs")

	# Preserve every original check above; exercise the added topic/priority paths.
	var personality := Conversation.new()
	personality.respond("are you alive", {})
	check(personality.respond("stop talking", {}).end_conversation and personality.memory.branch.is_empty(), "leave closes an active branch")
	check(personality.respond("yes", {}).line_id != "alive_follow", "yes cannot resurrect a closed branch")
	personality.respond("are you alive", {})
	check(personality.respond("inventory", {}).line_id == "inventory_empty" and personality.memory.branch.is_empty(), "authoritative new topic closes old branch")
	personality.respond("are you alive", {})
	check(personality.respond("open hot valve does it matter", context).line_id == "action_boundary", "followup phrase inside physical command cannot hijack authority")
	check(personality.respond("i need a moment", {}).line_id == "hesitate", "hesitation opens authored branch")
	check(personality.respond("tell me more", {}).line_id == "hesitate_more", "hesitation develops without diagnosing the player")
	check(personality.respond("do we have to talk", {}).line_id == "hesitate_quiet", "quiet choice remains a specific branch fork")
	check(personality.respond("help", context).text == context.objective, "help always preserves supplied objective")
	check(personality.respond("xyzzy", {}).line_id == "magic_word", "classic command has bounded response")
	check(personality.respond("undo", {}).line_id == "undo_request", "undo cannot change world state")
	check(personality.respond("tell me a joke", {}).line_id == "joke_request" and personality.respond("another joke", {}).line_id == "joke_again", "repeated joke is acknowledged rather than replayed")
	check(personality.respond("your printer is jammed", {}).line_id == "jam", "player can discuss a reported jam without asserting a repair")
	check(personality.respond("is it my fault", {}).line_id == "jam_fault", "mechanical fault has an authored humane fork")
	var events := Conversation.new()
	var event_ids: Array[String] = []
	for index in 3: event_ids.append(str(events.event("hesitation").line_id))
	check(event_ids.size() == 3 and event_ids[0] != event_ids[1] and events.event("hesitation").is_empty(), "hesitation repertoire exhausts into silence")
	var reloaded := Conversation.new()
	check(reloaded.memory.restore(events.memory.snapshot()) and reloaded.event("hesitation").is_empty(), "event exhaustion survives memory roundtrip")
	var dated := {"weather_report":"Observed cold; issued forecast unchanged.", "weather_comment_id":"weather_comment_cold"}
	var dated_original := dated.duplicate(true)
	var first_weather: String = personality.respond("weather", dated).text
	check(first_weather.begins_with(dated.weather_report) and first_weather.contains("draught") and dated == dated_original, "dated comment appends without altering factual report or context")
	check(personality.respond("weather", dated).text == dated.weather_report, "weather facts repeat on request while comment stays quiet")
	check(personality.respond("newspaper", {}).line_id == "newspaper_unavailable", "no supplied page means no invented newspaper")
	check(personality.respond("newspaper", {"newspaper_report":"Dated headline", "newspaper_comment_id":"alive"}).text == "Dated headline", "calendar witness cannot select unrelated personality prose")
	var failures := 0
	for record: Dictionary in checks:
		if not record.passed: failures += 1
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty(): out = "user://tests/companion"
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("conversation_diagnostic.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"evidence_class":"INERT", "checks":checks, "failures":failures}, "\t"))
	print("COMPANION OFFLINE DIAGNOSTIC: ", checks.size(), " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

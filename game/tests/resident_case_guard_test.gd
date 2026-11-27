extends Node3D
## Speaking to a resident's body never opens a case that is switched off (order w715d783b50d8): Rhea's and
## Cal's cases stay unseen with no work order; Mina's enabled case still opens. A real AnimatedResident is
## built and its interact() called, as the player's interaction does.
const WHO_OFF: Array[String] = ["rhea_sato", "cal_dwyer"]
const WHO_ON := "mina_vale"

var checks := 0
var failures: Array[String] = []
var opened: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("CASE GUARD: [FAIL] ", text)


func _ready() -> void:
	run.call_deferred()


func _stage(resident_id: String) -> String:
	return str(RealityState.case_state(RealityCases.case_for_resident(resident_id)).get("stage", "unseen"))


func _talk(resident_id: String) -> void:
	var actor := AnimatedResident.new()
	actor.setup(resident_id.capitalize(), resident_id, "", CastBodies.old_model(resident_id))
	actor.externally_driven = true
	add_child(actor)
	await get_tree().process_frame
	check(actor.interact_prompt().is_empty() == (resident_id != WHO_ON), "%s offers body interaction only for an enabled case" % resident_id)
	actor.interact(null)
	await get_tree().process_frame
	actor.queue_free()


func run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityCases.work_order_opened.connect(func(case_id: String) -> void: opened.append(case_id))
	for who: String in WHO_OFF:
		var case_id := RealityCases.case_for_resident(who)
		check(not bool(RealityCases.definition(case_id).get("enabled", false)), "%s's case is switched off" % who)
		check(_stage(who) == "unseen", "%s's case starts unseen" % who)
		await _talk(who)
		check(_stage(who) == "unseen", "speaking to %s leaves the case unseen (now %s)" % [who, _stage(who)])
		check(not opened.has(case_id), "no work order for %s's case" % who)
	var mina_case := RealityCases.case_for_resident(WHO_ON)
	check(bool(RealityCases.definition(mina_case).get("enabled", false)), "Mina's case is enabled")
	await _talk(WHO_ON)
	check(_stage(WHO_ON) == "active" and opened.has(mina_case), "speaking to Mina still opens her enabled case")
	print("CASE GUARD RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)

extends Node
## Adela's attachments (design/ORISON_ADELA_ATTACHMENTS_2026-11-22.md): a
## released attachment queues its resident's release print, CoreLoopDirector
## arms one at a time with its slot by release order, sleep enters it through
## DreamDirector, and the wake reconciles through the release boundary without
## touching Mina's job loop. No world: the real coordinator, the real dream
## transaction owner and the real campaign state.
var failures: Array[String] = []
var checks := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])


func _dream_through(dreams: DreamDirector) -> bool:
	return dreams.enter_armed_dream() and dreams.notify_dream_world_active() \
			and dreams.end_dream("capture") and dreams.complete_return()


func _ready() -> void:
	var old_data: Dictionary = RealityState.data
	var old_persistence: bool = RealityState.persistence_enabled
	RealityState.persistence_enabled = false
	RealityState.start_new_campaign()

	var loop := CoreLoopDirector.new()
	add_child(loop)
	var dreams := DreamDirector.new()
	add_child(dreams)
	dreams.setup(loop)
	var requested: Array[String] = []
	loop.dream_requested.connect(func(_case: String, profile: String, _window: Dictionary) -> void:
		requested.append(profile))

	check(not loop.request_release_dream("lena_visible_patch") and not loop.request_release_dream(""),
			"only the six residents' release prints are attachments")
	check(loop.request_release_dream("peter_release_print"), "Peter's clause queues his release print")
	check(not loop.request_release_dream("peter_release_print"), "asking again for a queued print is refused")
	check(loop.request_release_dream("juno_release_print"), "Juno's song queues behind it")
	loop._process(0.0)
	var context := dreams.context()
	check(dreams.phase() == "armed" and context.profile_id == "peter_release_print"
			and context.case_id == "peter_form_corridor" and int(context.window.get("campaign_slot", 0)) == 1,
			"the first release arms Peter's print, bound to his own case, as the first slot")
	loop._process(0.0)
	check(requested == ["peter_release_print"] and dreams.context().profile_id == "peter_release_print",
			"one dream is armed at a time; the second waits")
	var boundary_before := loop.boundary()
	check(_dream_through(dreams), "sleep enters the armed print and the wake reconciles through the release boundary")
	var state := loop.loop_state()
	check(dreams.phase() == "awake" and state.release_dreams_done == ["peter_release_print"]
			and (state.release_dreams as Array).size() == 1 and loop.boundary() == boundary_before,
			"waking records Peter's print as dreamed and leaves Mina's job loop where it was")
	check(not loop.request_release_dream("peter_release_print"), "a dreamed print is never queued again")
	loop._process(0.0)
	context = dreams.context()
	check(dreams.phase() == "armed" and context.profile_id == "juno_release_print"
			and int(context.window.get("campaign_slot", 0)) == 2,
			"the next night arms Juno's print as the second slot, by release order")

	# A restored coordinator finds the armed print already in flight and does
	# not ask for it twice.
	var restored := CoreLoopDirector.new()
	add_child(restored)
	var restored_requests := 0
	restored.dream_requested.connect(func(_c: String, _p: String, _w: Dictionary) -> void:
		restored_requests += 1)
	restored._process(0.0)
	restored._process(0.0)
	check(restored_requests == 0 and dreams.context().profile_id == "juno_release_print",
			"a restore with the print already armed sends no second request")
	check(_dream_through(dreams) and loop.loop_state().release_dreams_done == ["peter_release_print", "juno_release_print"]
			and (loop.loop_state().release_dreams as Array).is_empty(), "Juno's print is dreamed and the queue is empty")
	loop._process(0.0)
	check(dreams.phase() == "awake", "nothing further is armed")

	# Slot by release order: the third print dreamed is slot 3 whoever it is.
	check(loop.request_release_dream("omar_release_print"), "Omar's bell queues")
	loop._process(0.0)
	check(int(dreams.context().window.get("campaign_slot", 0)) == 3 and dreams.context().case_id == "omar_unrepairable",
			"Omar's print, released third, is the third slot")

	RealityState.data = old_data
	RealityState.persistence_enabled = old_persistence
	print("[RELEASE DREAM QUEUE] RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

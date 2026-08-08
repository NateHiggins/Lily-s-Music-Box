extends Node
## Does the building actually shove the torch?
##
## PhoneLightMask.punch() was written, tuned and shipped with NOTHING
## CALLING IT. That is the failure this file exists to prevent, and it
## is a failure with no symptom: the beam simply never reacts, which
## looks exactly like a beam that is not supposed to react. The mask
## itself had already been silently dead once before for a different
## reason (a bare Control issues no draw call, so its shader never ran),
## so this system has now failed invisibly twice.
##
## So: fire a real intrusion through the real SanityDirector and demand
## the surge move. Not a unit test of punch() — that would pass while
## the signal stayed unconnected, which is precisely the bug.

var root: Node3D
var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.4).timeout
	_run()


func _run() -> void:
	var mask: PhoneLightMask = root.player._light_mask
	_check("the player is carrying a light mask", mask != null)
	if mask == null:
		print("[PUNCH] RESULT: FAIL (%d failures)" % _fails)
		get_tree().quit(1)
		return

	# It has to have found the director on its own — the connection is
	# made lazily, wherever the mask first sees a building.
	_check("the mask found the sanity director", mask._sanity != null)
	_check("and connected to intrusions",
			mask._sanity != null
			and mask._sanity.intruded.is_connected(mask._on_intruded))
	_check("and to unwitnessed ones",
			mask._sanity != null
			and mask._sanity.attention_withheld.is_connected(
					mask._on_withheld))

	# The beam must not move unless the building moved it. Written as
	# "unless" rather than "never": the director is live in here and is
	# entitled to fire during the window, so counting what it actually
	# did is the only version of this check that is not a coin toss.
	var fired := [0]
	var spy := func(_c: String, _n: int) -> void: fired[0] += 1
	root.sanity.intruded.connect(spy)
	root.sanity.attention_withheld.connect(spy)
	mask._surge = 0.0
	for i in 8:
		await get_tree().process_frame
	root.sanity.intruded.disconnect(spy)
	root.sanity.attention_withheld.disconnect(spy)
	_check("the beam moves only when the building moves it (%d events)"
			% fired[0], mask._surge <= 0.001 or fired[0] > 0)

	# Now the building does something.
	mask._surge = 0.0
	root.sanity.intruded.emit("noel_domestic_museum", 1)
	_check("a rung one is felt", mask._surge > 0.0)
	var soft: float = mask._surge

	mask._surge = 0.0
	root.sanity.intruded.emit("noel_domestic_museum", 4)
	_check("a rung four is felt harder than a rung one (%.2f > %.2f)"
			% [mask._surge, soft], mask._surge > soft)
	_check("and never past full", mask._surge <= 1.0)

	# Ignoring it does not make it quieter.
	mask._surge = 0.0
	root.sanity.attention_withheld.emit("noel_domestic_museum", 1)
	var once: float = mask._surge
	mask._surge = 0.0
	root.sanity.attention_withheld.emit("noel_domestic_museum", 3)
	_check("a longer streak of ignoring leans harder (%.2f > %.2f)"
			% [mask._surge, once], mask._surge > once)
	_check("and still never past full", mask._surge <= 1.0)

	# The shove decays rather than sticking.
	mask._surge = 1.0
	for i in 4:
		await get_tree().process_frame
	_check("the shove fades (%.2f)" % mask._surge, mask._surge < 1.0)

	print("[PUNCH] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)

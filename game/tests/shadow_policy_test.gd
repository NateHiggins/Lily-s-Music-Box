extends Node
## The comic world's lamp-only shadows go through the light owners
## (scripts/rendering/shadow_policy.gd): an owner's wish survives the look,
## the lamp keeps its shadow, a light built while lamp-only is on is caught,
## and switching back hands every light its owner's wish.

const ShadowPolicy := preload("res://scripts/rendering/shadow_policy.gd")

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func _light(name: String, shadow: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = name
	light.shadow_enabled = shadow
	add_child(light)
	return light


func _run() -> void:
	var lamp := SpotLight3D.new()
	lamp.name = "Lamp"
	lamp.shadow_enabled = true
	lamp.add_to_group(ShadowPolicy.KEEP_GROUP)
	add_child(lamp)
	var authored := _light("Authored", true)
	var unshadowed := _light("Unshadowed", false)
	var budgeted := _light("Budgeted", true)

	ShadowPolicy.set_lamp_only(get_tree(), true)
	_check("lamp-only keeps the lamp's shadow", lamp.shadow_enabled)
	_check("lamp-only withholds an authored shadow", not authored.shadow_enabled)
	_check("the authored wish is remembered", ShadowPolicy.wanted(authored))
	_check("an unshadowed light stays unshadowed", not unshadowed.shadow_enabled and not ShadowPolicy.wanted(unshadowed))

	# An owner (a light rig budget) asks for its shadow every frame.
	for i in 3:
		ShadowPolicy.set_shadow(budgeted, true)
		await get_tree().process_frame
	_check("an owner's repeated ask does not fight the look", not budgeted.shadow_enabled)
	ShadowPolicy.set_shadow(budgeted, false)
	_check("an owner can withdraw its wish under lamp-only", not ShadowPolicy.wanted(budgeted))

	# A builder adds a light and sets its shadow after add_child.
	var late := OmniLight3D.new()
	late.name = "Late"
	add_child(late)
	late.shadow_enabled = true
	await get_tree().process_frame
	await get_tree().process_frame
	_check("a light built under lamp-only loses its shadow", not late.shadow_enabled)
	_check("and keeps its builder's wish", ShadowPolicy.wanted(late))

	ShadowPolicy.set_lamp_only(get_tree(), false)
	_check("off restores the authored shadow", authored.shadow_enabled)
	_check("off restores the late light's shadow", late.shadow_enabled)
	_check("off honours a wish withdrawn under lamp-only", not budgeted.shadow_enabled)
	_check("off leaves the unshadowed light alone", not unshadowed.shadow_enabled)
	_check("the lamp keeps its shadow throughout", lamp.shadow_enabled)
	ShadowPolicy.set_shadow(budgeted, true)
	_check("with lamp-only off an owner's write applies at once", budgeted.shadow_enabled)

	print("SHADOW POLICY TEST: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

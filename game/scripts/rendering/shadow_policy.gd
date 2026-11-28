extends RefCounted
## Which lights may cast a shadow under the current world look (Lily
## 2026-11-28: in the comic world Vantry's lamp is the only shadow caster).
##
## Every light owner keeps its own authority over whether it WANTS a shadow
## (light rig budgets, far-light reach, the sky key's day/night hysteresis, the
## shop and street lamps). Those owners write through set_shadow(), which
## records the wish on the light and applies it unless the look forbids it.
## Owners that read a light's authored shadow read wanted(), so switching the
## look never teaches an owner that a light had no shadow. Lights that only set
## a shadow when they are built are caught by the sweep and by the tree's
## node_added signal while lamp_only is on. Nothing here runs per frame.
##
## The lamp lights (the player's lamp and every LampOpticalInstrument beam)
## join KEEP_GROUP where they are built.

const WANT_META := &"orison_shadow_wanted"
const KEEP_GROUP := &"lamp_shadow_caster"

static var lamp_only := false


static func is_kept(light: Light3D) -> bool:
	return light.is_in_group(KEEP_GROUP)


static func allowed(light: Light3D, wanted_shadow: bool) -> bool:
	return wanted_shadow and (not lamp_only or is_kept(light))


## The owner's write. Returns the shadow actually applied.
static func set_shadow(light: Light3D, wanted_shadow: bool) -> bool:
	if light == null:
		return false
	light.set_meta(WANT_META, wanted_shadow)
	var applied := allowed(light, wanted_shadow)
	if light.shadow_enabled != applied:
		light.shadow_enabled = applied
	return applied


## The shadow the light's owner wants, whatever the look currently allows.
static func wanted(light: Light3D) -> bool:
	if light.has_meta(WANT_META):
		return bool(light.get_meta(WANT_META))
	return light.shadow_enabled


## Switch lamp-only on or off for every light in the tree. On records each
## light's current shadow as its owner's wish (with lamp-only off, the two are
## the same); off hands each light back the shadow its owner last asked for.
static func set_lamp_only(tree: SceneTree, value: bool) -> int:
	if value == lamp_only and (tree == null or tree == _watcher_tree()):
		return 0
	lamp_only = value
	if _watcher == null:
		_watcher = Watcher.new()
		_watcher.policy = load("res://scripts/rendering/shadow_policy.gd")
	_watcher.watch(tree if value else null)
	if tree == null:
		return 0
	var changed := 0
	for node: Node in tree.root.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if value:
			light.set_meta(WANT_META, light.shadow_enabled)
		changed += apply(light)
	return changed


## Bring one light into line with the look. Returns 1 when it changed.
static func apply(light: Light3D) -> int:
	if light == null or not is_instance_valid(light):
		return 0
	var applied := allowed(light, wanted(light))
	if light.shadow_enabled == applied:
		return 0
	light.shadow_enabled = applied
	return 1


static var _watcher: Watcher


static func _watcher_tree() -> SceneTree:
	return _watcher.tree if _watcher != null else null


## Builders set shadow_enabled after add_child, so a light added while
## lamp-only is on is looked at once, after the frame's scripts have run.
class Watcher extends RefCounted:
	var tree: SceneTree
	var policy: Script
	var pending: Array[Light3D] = []

	func watch(next: SceneTree) -> void:
		if tree != null and tree.node_added.is_connected(_added):
			tree.node_added.disconnect(_added)
		tree = next
		pending.clear()
		if tree != null:
			tree.node_added.connect(_added)

	func _added(node: Node) -> void:
		if not (node is Light3D):
			return
		var light := node as Light3D
		if not light.has_meta(policy.WANT_META):
			# A light no owner has spoken for yet: whatever its builder sets
			# before the frame ends is the wish.
			pending.append(light)
			if not tree.process_frame.is_connected(_settle):
				tree.process_frame.connect(_settle, CONNECT_ONE_SHOT)
		else:
			policy.apply(light)

	func _settle() -> void:
		var lights := pending.duplicate()
		pending.clear()
		for light: Light3D in lights:
			if is_instance_valid(light) and light.is_inside_tree() and policy.lamp_only:
				if not light.has_meta(policy.WANT_META):
					light.set_meta(policy.WANT_META, light.shadow_enabled)
				policy.apply(light)

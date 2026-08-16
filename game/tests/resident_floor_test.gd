extends Node
## TASKS.md V4: a resident who leaves their home storey must be culled with
## the storey they OCCUPY, not the one they spawned on.
##
## Residents spawn under floor_nodes[home] and, before this fix, nothing ever
## moved them - so anyone routed to the bar, the roof or the laundry stayed
## parented to their flat's storey and inherited the wrong visibility answer.
## Tests papered over it with show_all_floors; this one refuses to.
##
## The mechanism is exercised exactly the way the routines produce it in
## play: the actor's node is placed at another storey's height (mid-trip
## positions are just positions - stair_route moves y continuously) and one
## _process step must reparent it under the occupied floor with its global
## position intact.

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
	await get_tree().create_timer(1.6).timeout
	await _run()


func _run() -> void:
	var routines: Node = root.resident_routines
	_check("routines exist", routines != null)
	_check("floor nodes are bound (V4 wiring)",
			routines != null and not routines._floor_nodes.is_empty())
	if routines == null or routines.actors.is_empty():
		print("[RESIDENT FLOOR] RESULT: FAIL (no actors)")
		get_tree().quit(1)
		return

	var actor: Dictionary = routines.actors[0]
	var node: Node3D = actor.node
	var home_parent: Node = node.get_parent()
	var home_fid: String = routines.nav.floor_at(node.global_position.y)
	_check("the actor starts parented to its home storey (%s)" % home_fid,
			home_parent == routines._floor_nodes.get(home_fid))

	# Choose a destination storey that is not home.
	var dest_fid := ""
	for fid in routines._floor_nodes:
		if fid != home_fid:
			dest_fid = fid
			break
	_check("a second storey exists to travel to", dest_fid != "")

	# Put the actor at the destination storey's height, exactly as a
	# stair_route leg would, and let one frame of routines run.
	var dest_z: float = routines.nav.floors[dest_fid].z
	var was := node.global_position
	node.global_position = Vector3(was.x, dest_z + 0.03, was.z)
	var expect := node.global_position
	routines._keep_floor_parent(actor)
	_check("one step reparents to the occupied storey (%s)" % dest_fid,
			node.get_parent() == routines._floor_nodes[dest_fid])
	_check("reparenting preserves the global position",
			node.global_position.distance_to(expect) < 0.001)

	# The point of the exercise: visibility now follows the OCCUPIED floor.
	var dest_node: Node3D = routines._floor_nodes[dest_fid]
	var home_node: Node3D = routines._floor_nodes[home_fid]
	var dest_prior := dest_node.visible
	var home_prior := home_node.visible
	dest_node.visible = false
	home_node.visible = true
	_check("hidden occupied storey hides the traveller",
			not node.is_visible_in_tree())
	dest_node.visible = true
	home_node.visible = false
	_check("a visible occupied storey shows them, home hidden or not",
			node.is_visible_in_tree())
	dest_node.visible = dest_prior
	home_node.visible = home_prior

	# And the walk home reverses it through the same mechanism.
	node.global_position = was
	routines._keep_floor_parent(actor)
	_check("returning home reparents back (%s)" % home_fid,
			node.get_parent() == routines._floor_nodes[home_fid])

	print("[RESIDENT FLOOR] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)

extends Node
## The anchor adapter's name index answers exactly what a real traversal
## answers, through every way the tree can change under it.
const Adapter := preload("res://scripts/building/orison_v2_anchor_adapter.gd")

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


## Every name the traversal can see, plus a few it cannot, must resolve to the
## same node (or null) through the index as through find_children.
func _agrees(adapter: Adapter, label: String, extra: Array = []) -> void:
	var names: Dictionary = {}
	for node: Node in adapter.root.find_children("*", "", true, false):
		names[str(node.name)] = true
	for name: String in extra:
		names[name] = true
	for name: String in names:
		var matches := adapter.root.find_children(name, "", true, false)
		var expected: Node = matches[0] if matches.size() == 1 else null
		_check(adapter.resolve(name) == expected, "%s: %s" % [label, name])


func _ready() -> void:
	var root := Node3D.new()
	root.name = "Root"
	add_child(root)
	var a := Node3D.new(); a.name = "A"; root.add_child(a)
	var b := Node3D.new(); b.name = "B"; a.add_child(b)
	var adapter := Adapter.new(root)
	_check(adapter.resolve("B") == b, "resolves a nested node")
	_check(adapter.resolve("Root") == null, "the root itself is not its own descendant")
	_agrees(adapter, "initial", ["Missing"])

	# Added after the index exists, including a whole subtree at once.
	var c := Node3D.new(); c.name = "C"
	var d := Node3D.new(); d.name = "D"; c.add_child(d)
	b.add_child(c)
	_check(adapter.resolve("D") == d, "a subtree added later is indexed")

	# A duplicate name anywhere makes the name ambiguous, then unique again.
	var twin := Node3D.new(); twin.name = "D"; a.add_child(twin)
	_check(adapter.resolve("D") == null, "two nodes named alike resolve to neither")
	_agrees(adapter, "duplicate")
	a.remove_child(twin)
	_check(adapter.resolve("D") == d, "removing the twin restores the answer")

	# Renames move the node between names.
	d.name = "Renamed"
	_check(adapter.resolve("D") == null and adapter.resolve("Renamed") == d, "a rename moves the entry")
	_agrees(adapter, "rename", ["D"])

	# Reparenting inside the root keeps it; moving outside drops it.
	d.reparent(a)
	_check(adapter.resolve("Renamed") == d, "reparenting inside the root keeps the node")
	var outside := Node3D.new(); outside.name = "Outside"; add_child(outside)
	d.reparent(outside)
	_check(adapter.resolve("Renamed") == null, "moving a node out of the root drops it")
	var stray := Node3D.new(); stray.name = "Stray"; outside.add_child(stray)
	_check(adapter.resolve("Stray") == null, "nodes outside the root are never indexed")

	# Freed nodes leave the index.
	c.queue_free()
	await get_tree().process_frame
	_check(adapter.resolve("C") == null, "a freed node is gone")
	_agrees(adapter, "after free", ["C", "Renamed"])

	# Patterns still take the real traversal.
	_check(adapter.resolve("B*") == b, "a wildcard pattern still matches")

	# A detached root answers by traversal and rebuilds when it returns.
	remove_child(root)
	var late := Node3D.new(); late.name = "Late"; b.add_child(late)
	_check(adapter.resolve("Late") == late, "a detached root answers by traversal")
	add_child(root)
	_check(adapter.resolve("Late") == late, "the index rebuilds when the root returns")
	_agrees(adapter, "rejoined", ["Missing"])

	# A second adapter over the same root shares the one index.
	var other := Adapter.new(root)
	_check(other.resolve("B") == b and root.get_meta(Adapter.NameIndex.META) != null, "adapters share one index")

	root.queue_free()
	outside.queue_free()
	await get_tree().process_frame
	print("[V2 NAME INDEX] RESULT: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	get_tree().quit(1 if _fails else 0)

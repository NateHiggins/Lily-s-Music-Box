extends RefCounted
## Exact-name index of one root's live descendants, kept current by the scene
## tree's own add, remove and rename notices. It answers the same question as
## root.find_children(name, "", true, false) for a literal name, without walking
## the whole world: the V2 anchor adapter resolved names thousands of times
## during startup, each a full traversal of a tree that grows as it composes.
##
## It holds nodes, never transforms, so callers still read fresh positions. It
## serves only while its root is inside the tree; a detached root goes back to
## a real traversal, and the index rebuilds when the root returns.

const META := &"_v2_name_index"

var _root: Node
var _by_name: Dictionary = {}  # String -> {instance id: Node}
var _name_of: Dictionary = {}  # instance id -> String
var _live := false


func _init(root: Node) -> void:
	_root = root


## The single live descendant with exactly this name, else null (none or many).
func unique(identity: String) -> Node:
	var bucket: Variant = _by_name.get(identity)
	return bucket.values()[0] if bucket != null and bucket.size() == 1 else null


## True when the index serves answers; rebuilds it after the root returns.
func ensure_live() -> bool:
	if _live:
		return true
	if not is_instance_valid(_root) or not _root.is_inside_tree():
		return false
	var tree := _root.get_tree()
	_by_name.clear()
	_name_of.clear()
	for node: Node in _root.find_children("*", "", true, false):
		_add(node)
	if not tree.node_added.is_connected(_on_added):
		tree.node_added.connect(_on_added)
		tree.node_removed.connect(_on_removed)
		tree.node_renamed.connect(_on_renamed)
	_live = true
	return true


func _add(node: Node) -> void:
	var key := str(node.name)
	var id := node.get_instance_id()
	_name_of[id] = key
	var bucket: Variant = _by_name.get(key)
	if bucket == null:
		_by_name[key] = {id: node}
	else:
		bucket[id] = node


func _drop(node: Node) -> void:
	var id := node.get_instance_id()
	var key: Variant = _name_of.get(id)
	if key == null:
		return
	_name_of.erase(id)
	var bucket: Dictionary = _by_name.get(key, {})
	bucket.erase(id)
	if bucket.is_empty():
		_by_name.erase(key)


func _on_added(node: Node) -> void:
	if _live and _root.is_ancestor_of(node):
		_add(node)


func _on_removed(node: Node) -> void:
	if not _live:
		return
	if node == _root:
		# The root is leaving the tree: stop serving until it comes back, when
		# the index rebuilds from a real traversal.
		_live = false
		_by_name.clear()
		_name_of.clear()
		return
	_drop(node)


func _on_renamed(node: Node) -> void:
	if not _live or not _name_of.has(node.get_instance_id()):
		return
	_drop(node)
	_add(node)

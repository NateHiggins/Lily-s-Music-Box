class_name SwcViewModes
extends RefCounted

## The developer toggle the spec asks for (§11), and the single most useful thing
## in the project: being able to strip every generated asset and land back on the
## graybox instantly is how you prove a skin changed nothing mechanical.
##
##   F1  semantic graybox
##   F2  compiled presentation
##   F3  semantic labels on/off
##
## `apply_degrade` is the same idea with a dial instead of a switch. Every entity
## gets a stable threshold in 0..1 derived from its semantic id, and falls back to
## its graybox once the degrade amount passes it. At 0.0 the world is fully
## dressed, at 1.0 it is the authored graybox, and in between it is a world coming
## apart in a fixed order - the same entities go first every time, so a corroding
## world reads as decay rather than as flicker.
##
## Nothing here touches collision, transforms or gameplay scripts. Those are
## siblings of the two nodes this file toggles, which is why "the skin fell off"
## can never mean "the level changed".

const GROUP_GRAYBOX := "swc_graybox"
const GROUP_PRESENTATION := "swc_presentation"
const GROUP_LABELS := "swc_labels"

enum Mode { GRAYBOX, PRESENTATION }

## The degrade level currently applied to the tree. Scene-wide display state, so
## it is readable by anything that builds a skin *after* the sweep has run - an
## enemy spawned into an already-corroded world has to arrive corroded, not snap
## to full dressing until the next change.
static var level: float = 0.0


static func apply(tree: SceneTree, mode: Mode, labels_visible: bool) -> void:
	apply_degrade(tree, 1.0 if mode == Mode.GRAYBOX else 0.0, labels_visible)


## `amount` 0.0 = fully dressed, 1.0 = fully graybox.
static func apply_degrade(tree: SceneTree, amount: float, labels_visible: bool) -> void:
	level = clampf(amount, 0.0, 1.0)
	for node in tree.get_nodes_in_group(GROUP_GRAYBOX):
		var graybox := node as Node3D
		graybox.visible = _stripped(graybox, level)
	for node in tree.get_nodes_in_group(GROUP_PRESENTATION):
		var skin := node as Node3D
		skin.visible = not _stripped(skin, level)
	for node in tree.get_nodes_in_group(GROUP_LABELS):
		(node as Node3D).visible = labels_visible


## Where a single entity sits on the ladder, for callers that degrade one node at
## a time rather than sweeping the tree (the enemies a spawner produces, say).
static func is_stripped(entity_id: String, amount: float) -> bool:
	return threshold_for(entity_id) < clampf(amount, 0.0, 1.0)


## A stable 0..1 position in the collapse order. FNV-1a over the id: cheap, and
## it scatters neighbouring ids instead of degrading a wall run left to right.
static func threshold_for(entity_id: String) -> float:
	var hash_value := 2166136261
	for i in entity_id.length():
		hash_value = (hash_value ^ entity_id.unicode_at(i)) & 0xFFFFFFFF
		hash_value = (hash_value * 16777619) & 0xFFFFFFFF
	return float(hash_value) / 4294967296.0


static func _stripped(node: Node3D, level: float) -> bool:
	# The two roots are siblings under the SwcEntity, so the parent's name is
	# the semantic id and both sides of a pair agree without extra bookkeeping.
	if level <= 0.0:
		return false
	if level >= 1.0:
		return true
	var owner_node := node.get_parent()
	return threshold_for(owner_node.name if owner_node != null else node.name) < level


static func mode_name(mode: Mode) -> String:
	return "SEMANTIC GRAYBOX" if mode == Mode.GRAYBOX else "COMPILED PRESENTATION"

class_name InspectableZone
extends StaticBody3D
## A thing worth a second look. Stands in front of batched geometry the
## way the lobby bench does and owns the verb: examine. The observation
## arrives as a lower-third line that holds long enough to read and then
## gets out of the way — the building's own captioning voice, not a modal.
##
## Multiple lines cycle in order across interactions, so a picture can
## have a second reading for whoever comes back to it.

var title := ""
var lines: Array = []
var _next := 0


func setup(zone_title: String, zone_lines: Array,
		size := Vector3(0.8, 0.8, 0.4)) -> void:
	title = zone_title
	lines = zone_lines
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)


func interact_prompt() -> String:
	return "[E]  Look at %s" % title


func interact(_player: Node) -> Dictionary:
	if lines.is_empty():
		return {}
	var line := str(lines[_next % lines.size()])
	_next += 1
	return {
		"title": title,
		"body": line,
		"stamp": "OBSERVATION",
	}

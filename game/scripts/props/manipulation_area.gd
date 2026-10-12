extends Area3D
## Exact moving part target. No appliance state or click-to-toggle fallback.
var provider: Callable

func manipulation_target(_hit: Dictionary) -> Dictionary:
	return provider.call() if provider.is_valid() else {}

static func install(part: Node3D, descriptor: Callable) -> Area3D:
	var area := load("res://scripts/props/manipulation_area.gd").new() as Area3D
	area.name = "ManipulationTarget"
	area.provider = descriptor
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	area.add_to_group("functional_interaction_areas")
	part.add_child(area)
	# Separate mesh bounds preserve gaps between disjoint pieces; no whole-prop
	# interaction box covers the hinges, open cabinet or neighbouring control.
	var draws := part.find_children("*","MeshInstance3D",true,false)
	if part is MeshInstance3D: draws.push_front(part)
	for draw: MeshInstance3D in draws:
		if draw.mesh == null: continue
		var shape := BoxShape3D.new()
		var bounds := draw.get_aabb()
		shape.size = bounds.size.max(Vector3.ONE*.008)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		area.add_child(collision)
		collision.global_transform = draw.global_transform * Transform3D(Basis(),bounds.get_center())
	return area

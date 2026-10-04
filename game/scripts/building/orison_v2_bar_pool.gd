extends RefCounted
## The retained bar keeps its cell, actors and original source identities.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return preload("res://scripts/building/orison_v2_shop_seating.gd").mount_bar_pool(cell,layout)

static func fit_inspection(zone: InspectableZone) -> bool:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/bar_pool.json"))
	if data is not Dictionary or data.get("inspection") is not Dictionary:return false
	var spec: Dictionary=data.inspection
	if spec.get("center") is not Array or spec.center.size()!=3 or spec.get("size") is not Array or spec.size.size()!=3:return false
	var center:=Vector3(spec.center[0],spec.center[1],spec.center[2])
	var size:=Vector3(spec.size[0],spec.size[1],spec.size[2])
	if not center.is_finite() or not size.is_finite() or minf(size.x,minf(size.y,size.z))<=0.:return false
	# The original large invisible StaticBody covered the chalk. Retain its
	# title, text and observation owner; let real table faces own collision.
	zone.collision_layer=0
	var area:=Area3D.new();area.name="FittedPoolInspection"
	area.collision_layer=1;area.collision_mask=0;area.monitoring=false;area.monitorable=false
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box
	area.add_child(shape);zone.add_child(area);area.position=center-zone.position
	return true

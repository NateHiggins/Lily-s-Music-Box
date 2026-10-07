extends RefCounted
const ShopSeating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if not ShopSeating.mount_diner_backbar(cell,layout):return false
	var model:=cell.get_node_or_null("DinerBackbar") as Node3D
	if model==null:return true
	# Fully metallic chrome needs the lit room to reflect. The cell owns
	# this single capture, so unload/reconstruction also retires its GPU owner.
	var floors: Array=layout.floors.filter(func(row):return row.id=="F01")
	var floor: Dictionary=floors[0].furniture.filter(func(row):return row.id=="storm_shop_luncheonette_floor")[0]
	var r: Array=floor.rect
	var probe:=ReflectionProbe.new()
	probe.name="DinerFinishReflection"
	probe.size=Vector3(r[2]-r[0],3.0,r[3]-r[1])
	probe.position=Vector3((r[0]+r[2])*.5,float(floor.z0)+float(floor.h)+1.5,-(r[1]+r[3])*.5)
	probe.max_distance=8.0
	probe.box_projection=true
	probe.interior=true
	probe.enable_shadows=false
	probe.update_mode=ReflectionProbe.UPDATE_ONCE
	model.add_child(probe)
	return true

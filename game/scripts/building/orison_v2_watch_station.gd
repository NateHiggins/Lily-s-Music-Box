extends WatchStationProp
## Visual replacement only; source station state, records, areas and sounds stay.
const STOCK := preload("res://assets/props/watch_stations.glb")
static var _stock: Dictionary = {}
var native_parts := 0
func _build_visual() -> void:
	super()
	if _stock.is_empty():
		var source := STOCK.instantiate()
		for draw: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):_stock[str(draw.name)]=draw.mesh
		source.free()
	for draw: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		var label := str(draw.name)
		if label.begins_with("WheelTooth"):label="WheelTooth"
		if _stock.has(label):draw.mesh=_stock[label];native_parts+=1
		elif label.begins_with("CaseCheek") or label=="ConduitElbow":draw.mesh=null
		elif draw.mesh is BoxMesh and draw.mesh.size.is_equal_approx(Vector3(.240,.020,.120)):draw.mesh=null
	# The original raised flag projects through the right cheek. Move its visual
	# pivot 38 mm inward; signal rotation/state and record authority are unchanged.
	_drop.position.x=.020
	_door.get_node("StationLegend").position.z+=.014
	for i in 3:
		var hinge := MeshInstance3D.new();hinge.name="NativeHinge%d" % i;hinge.mesh=_stock.HingeBarrel
		hinge.position=Vector3(0,-.10+i*.10,0);hinge.material_override=MatLib.get_mat("brass_dull")
		_door.add_child(hinge)
	set_meta("v2_native_watch_station",true)

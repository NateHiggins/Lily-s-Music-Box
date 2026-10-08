extends RefCounted
## Six original work lights reuse the accepted indoor cage/socket geometry.
## New native mounting arms terminate on the existing masonry or shed roof.
var installed: Array[Dictionary] = []
var errors: Array[String] = []

func mount(world: Node3D, fixed: RefCounted, instruments: RefCounted) -> bool:
	var source: Array = fixed._variants["cage_bulb_rise300"]
	for node: Node in world.find_children("*","Node3D",true,false):
		if not is_instance_valid(node): continue
		if not node is LightFixtureProp or node.has_meta("v2_native_fixed_light_variant"): continue
		var lamp := node as LightFixtureProp
		var parent := lamp.get_parent()
		if parent.get_script()==null: continue
		var script: String = parent.get_script().resource_path
		var variant := ""
		if script=="res://scripts/building/orison_v2_service_alley.gd":
			variant="AlleyEast" if lamp.position.x>17. else "AlleyWest"
		elif script=="res://scripts/building/orison_v2_street_boundaries.gd" and str(lamp.name) in ["ShedEntryWorkLamp","ShedTurnWorkLamp"]: variant="Shed"
		if variant.is_empty(): continue
		var mount_part: Dictionary = instruments.work_light_parts[variant]
		var before := {"lamp":weakref(lamp),"variant":variant,"position":lamp.position,"light":lamp.light.get_instance_id(),"bounce":lamp.bounce.get_instance_id(),"halo":lamp._halo.get_instance_id(),"bulb_material":lamp._bulb_mat.get_instance_id(),"swing":lamp._swing_node.get_instance_id(),"light_pose":lamp.light.transform,"energy":lamp._base_energy,"range":lamp.light.omni_range,"navigation":lamp.navigation_light,"standby":lamp.standby_scale,"seat":mount_part.seat,"normal":mount_part.normal}
		for child: Node in lamp._swing_node.get_children():
			if child is MeshInstance3D and child!=lamp._halo: lamp._swing_node.remove_child(child);child.free()
		for part: Dictionary in source:
			if part.component=="Mount": continue
			var draw := MeshInstance3D.new()
			draw.name=str(part.name);draw.mesh=part.mesh;draw.transform=part.pose
			draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if part.component=="Bulb": draw.material_override=lamp._bulb_mat
			lamp._swing_node.add_child(draw)
		var mount_draw := MeshInstance3D.new()
		mount_draw.name="NativeWorkLightMount";mount_draw.mesh=mount_part.mesh
		mount_draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(mount_draw)
		lamp.set_meta("v2_native_work_light",variant)
		installed.append(before)
	if installed.size()!=6: errors.append("expected the four alley and two shed owners")
	return errors.is_empty()

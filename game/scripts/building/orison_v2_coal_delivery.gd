extends Node3D
## Closed pavement cover and gravity chute; the existing boiler owns firing.
const Model := preload("res://assets/building/v2_coal_delivery.glb")

func _ready() -> void:
	_mount_coal_heap()
	var model := Model.instantiate()
	add_child(model)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for index in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(index)
			if material != null and MatLib.SETS.has(material.resource_name):
				mesh.set_surface_override_material(index, MatLib.get_mat(material.resource_name))
		mesh.create_trimesh_collision()

func _mount_coal_heap() -> void:
	var heap := (preload("res://assets/props/coal_heap.glb") as PackedScene).instantiate()
	heap.name="FabricatedCoalHeap"
	add_child(heap)
	var finish: Material=MatLib.get_mat("soot")
	# Keep all authored identities; replace only the visible placeholder and
	# its broad box collision with the actual pile surface.
	for old: Node in get_parent().get_children():
		if not str(old.name).begins_with("B1_COAL_HEAP_"): continue
		if old is MeshInstance3D:
			finish=old.material_override
			old.hide()
		var collision := old.get_node_or_null("Collision") as StaticBody3D
		if collision!=null: collision.collision_layer=0;collision.collision_mask=0
	for mesh: MeshInstance3D in heap.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=finish
		mesh.create_trimesh_collision()

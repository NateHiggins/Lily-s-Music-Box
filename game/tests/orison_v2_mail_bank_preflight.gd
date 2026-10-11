extends Node
## Fast asset/mechanism preflight; this is not production composition proof.
class MountParent extends OrisonV2RuntimeRoot:
	func _ready() -> void: pass
	func _exit_tree() -> void: pass

var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("MAIL PREFLIGHT FAIL: " + label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	var parent := MountParent.new(); add_child(parent); parent.set_process(false); parent.set_physics_process(false)
	var bank := MailBankProp.new(); bank.set_meta("v2_mail_bank_visuals", true); parent.add_child(bank)
	check(bank.get_meta("v2_native_mail_bank", false), "original ready path installs native stock")
	if not bank.get_meta("v2_native_mail_bank", false): parent.free(); get_tree().quit(1); return
	check(bank._native_content_meshes.size() == 4, "all four delivery visual variants loaded")
	for draw: MeshInstance3D in bank.find_children("*", "MeshInstance3D", true, false): _check_mesh(draw.mesh)
	for mesh: Mesh in bank._native_content_meshes.values(): _check_mesh(mesh)
	check(bank._fixed.find_children("*", "MeshInstance3D", true, false).size() == 6, "fixed stock stays at six material draws")
	check(bank._fixed.get_node_or_null("HeaderLettering") != null and bank._fixed.get_node_or_null("FixedNameCards") != null, "source lettering survives batching")
	check(bank._hinge.get_node_or_null("PlayerNameCard") != null, "player card stays on its original hinge")
	var body := bank.get_node("PlayerBox") as StaticBody3D
	check(body.get_script().resource_path == "res://scripts/props/mail_box_zone.gd", "original use-ray authority survives")
	var shape := body.get_child(0) as CollisionShape3D
	check((shape.shape as BoxShape3D).size.is_equal_approx(Vector3(.31, .14, .20)), "original interaction volume survives")
	var pending := JSON.stringify(bank.pending()); var reality := JSON.stringify(RealityState.data)
	bank._set_door(true); await get_tree().create_timer(.45).timeout
	check(bank.door_open and is_equal_approx(bank._hinge.rotation.y, deg_to_rad(95.)), "original tween opens to 95 degrees")
	for item: MeshInstance3D in bank._contents.get_children():
		var material := item.get_active_material(0) as StandardMaterial3D
		check(item.has_meta("native_mail_content") and material != null and material.albedo_texture != null
				and material.normal_texture != null and material.roughness_texture != null, "pending delivery uses native custom PBR")
	bank._set_door(false); await get_tree().create_timer(.45).timeout
	check(not bank.door_open and is_zero_approx(bank._hinge.rotation.y), "original tween closes fully")
	check(JSON.stringify(bank.pending()) == pending and JSON.stringify(RealityState.data) == reality, "visual use does not change delivery custody")
	var retired: WeakRef = weakref(bank); parent.free(); await get_tree().process_frame
	check(retired.get_ref() == null, "native bank retires with its source parent")
	print("MAIL PREFLIGHT: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_mesh(mesh: Mesh) -> void:
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		check(uv.size() == vertices.size(), "imported chart covers every vertex")
		if uv.size() != vertices.size(): continue
		var bad := 0
		for offset in range(0, indices.size() if not indices.is_empty() else vertices.size(), 3):
			var a := indices[offset] if not indices.is_empty() else offset
			var b := indices[offset+1] if not indices.is_empty() else offset+1
			var c := indices[offset+2] if not indices.is_empty() else offset+2
			if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length_squared() > 1e-18:
				if absf((uv[b]-uv[a]).cross(uv[c]-uv[a])) < 1e-12: bad += 1
		check(bad == 0, "every nondegenerate imported triangle keeps nonzero UV area")

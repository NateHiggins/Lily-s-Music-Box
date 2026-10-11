extends RefCounted
## Visual stock only. Original door, use-ray, catalog and mail custody survive.
const MODEL := "res://assets/props/mail_bank.glb"
var meshes: Dictionary = {}
var materials: Dictionary = {}

func mount(bank: MailBankProp) -> bool:
	var packed := load(MODEL) as PackedScene
	if packed == null: return false
	var reference := packed.instantiate()
	for draw: MeshInstance3D in reference.find_children("*", "MeshInstance3D", true, false):
		if draw.mesh == null or draw.mesh.get_surface_count() != 1: reference.free(); return false
		var stock := draw.mesh.surface_get_material(0)
		var key := str(stock.resource_name)
		if not MatLib.SETS.has(key): reference.free(); return false
		if not materials.has(key):
			var finish := (bank._brass if key == "brass_dull" else MatLib.get_mat(key)).duplicate() as StandardMaterial3D
			finish.uv1_triplanar = false
			if key == "brass_dull": finish.uv1_scale = Vector3.ONE / .35
			finish.normal_scale = .035 if key in ["brass_dull", "nickel_plated"] else .10
			finish.roughness = .90 if key == "paper" else .52 if key == "wood_dark" else .65 if key == "iron_blackened" else .50
			materials[key] = finish
		var mesh := draw.mesh.duplicate() as Mesh
		mesh.surface_set_material(0, materials[key])
		meshes[str(draw.name)] = mesh
	reference.free()
	if meshes.size() != 20: return false
	for stock: String in ["EnvelopeStock", "WorkOrderStock", "ParcelStock", "ParcelBand"]:
		bank._native_content_meshes[stock] = meshes[stock]
	# Header and tenant-card UV crops are authoritative existing lettering.
	for draw: MeshInstance3D in bank._fixed.find_children("*", "MeshInstance3D", true, false):
		if draw.name not in [&"FixedNameCards", &"HeaderLettering"]:
			draw.get_parent().remove_child(draw); draw.free()
	for draw: MeshInstance3D in bank._hinge.find_children("*", "MeshInstance3D", true, false):
		if draw.name != &"PlayerNameCard":
			draw.get_parent().remove_child(draw); draw.free()
	# The procedural player-box body was a visual slab, separate from PlayerBox.
	for child: Node in bank.get_children():
		if child is MeshInstance3D: bank.remove_child(child); child.free()
	_part(bank._fixed, "TimberStile", Vector3(-.65, 1.235, -.025))
	_part(bank._fixed, "TimberStile", Vector3(.65, 1.235, -.025))
	_part(bank._fixed, "TimberLowerPanel", Vector3(0, .730, -.025))
	_part(bank._fixed, "TimberHeaderRail", Vector3(0, 1.845, -.025))
	_part(bank._fixed, "TimberCrown", Vector3(0, 1.917, -.059))
	_part(bank._fixed, "HeaderPlate", Vector3(0, 1.845, -.053))
	for unit: String in bank.CARD_ORDER:
		var col: int = bank.STACKS.find(unit[1])
		var at := Vector3((col - 1.5) * bank.DOOR_W,
				bank.ARRAY_BASE + (int(unit[0]) - .5) * bank.DOOR_H, 0)
		_part(bank._fixed, "PocketCase", at + Vector3(0, 0, bank.Z_LEAF))
		_part(bank._fixed, "CastFrame", at + Vector3(0, 0, -.116))
		_part(bank._fixed, "CarrierFlap", at + Vector3(0, .053, -.122), Vector3(-.14, 0, 0))
		for y in [-.033, .033]: _part(bank._fixed, "HingeBarrel", at + Vector3(-bank.LEAF_W * .5, y, bank.Z_LEAF))
		if unit in bank.EMPTY_UNITS: continue
		if unit == bank.PLAYER_UNIT:
			_leaf(bank._hinge, bank.LEAF_W, true)
		elif unit in bank.AJAR_UNITS:
			var hinge := Node3D.new(); hinge.name = "NativeAjar_" + unit
			hinge.position = at + Vector3(-bank.LEAF_W * .5, 0, bank.Z_LEAF)
			hinge.rotation.y = bank.AJAR_ANGLE; bank._fixed.add_child(hinge)
			_leaf(hinge, bank.LEAF_W, false)
		else:
			_part(bank._fixed, "LeafShell", at + Vector3(0, -.008, bank.Z_LEAF))
			_part(bank._fixed, "CardFrame", at + Vector3(0, .012, bank.Z_CARD_FRAME))
			_part(bank._fixed, "CylinderLock", at + Vector3(.105, -.039, bank.Z_LOCK))
			_part(bank._fixed, "KeywayBack", at + Vector3(.105, -.039, bank.Z_LOCK))
	_part(bank._fixed, "OutgoingPlate", Vector3(.38, .60, -.053))
	_part(bank._fixed, "OutgoingFlap", Vector3(.38, .594, -.060), Vector3(-.14, 0, 0))
	_part(bank._fixed, "OutgoingPocket", Vector3(.38, .615, -.047))
	# Give existing envelopes their true compartment depth, behind the closed leaf.
	bank._contents.position.z = -.063
	bank._contents.position.y -= .031
	bank.set_meta("v2_native_mail_bank", true)
	bank.set_meta("native_compartments", bank.CARD_ORDER.size())
	StaticMeshBatcher.merge(bank._fixed, [bank._fixed.get_node("FixedNameCards"), bank._fixed.get_node("HeaderLettering")])
	meshes.clear(); materials.clear()
	return true

func _leaf(parent: Node3D, width: float, player_card: bool) -> void:
	_part(parent, "LeafShell", Vector3(width * .5, -.008, 0))
	_part(parent, "CardFrame", Vector3(width * .5 - (.025 if player_card else 0), .012, -.006))
	_part(parent, "CylinderLock", Vector3(width * .5 + .105, -.039, -.007))
	_part(parent, "KeywayBack", Vector3(width * .5 + .105, -.039, -.007))

func _part(parent: Node3D, part: String, at: Vector3, angles := Vector3.ZERO) -> void:
	var draw := MeshInstance3D.new(); draw.name = part
	draw.mesh = meshes[part]; draw.position = at; draw.rotation = angles
	draw.material_override = draw.mesh.surface_get_material(0)
	draw.set_meta("native_mail_part", part); parent.add_child(draw)

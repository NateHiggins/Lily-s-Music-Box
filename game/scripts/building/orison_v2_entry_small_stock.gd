extends RefCounted
## Fixed stock in the measured blockout frame. The tray datums do not own input.

const SCRAPER := preload("res://assets/props/entry_boot_scraper.glb")
const UMBRELLA_STAND := preload("res://assets/props/entry_umbrella_stand.glb")
const STAND_ID := "F01_vestibule_umbrella_stand"
const STAND_VARIANT := "EntryUmbrellaStand"
const SCRAPER_SITE := Vector3(1.95, 0, -12.65)

# Catalogue key, metres per tile, normal strength, roughness, and linear tint
# where a retained domestic finish specifies one. The new iron follows the
# delivery's blackened frame and exposed working edge.
const FINISHES := {
	"iron_blackened": ["iron_blackened", .4, .35, 1.0],
	"iron_neutral": ["iron_neutral", .4, .15, .75],
	"brass": ["brass_dull", .5, .04, .5],
	"wood_dark": ["oak_work_surface", .9, .04, .5, Color(.27, .14, .065)],
	"cape_navy": ["linen", .6, .16, .9, Color(.05, .065, .16)],
	"coat_grey": ["linen", .6, .16, .9, Color(.22, .22, .23)],
}
const SCRAPER_PARTS := ["Body__iron_blackened", "Body__iron_neutral"]
const STAND_PARTS := ["DripTray__iron_blackened", "StandBody__brass",
	"StandBody__cape_navy", "StandBody__coat_grey", "StandBody__iron_blackened",
	"StandBody__wood_dark"]


static func mount_scraper(root: Node3D) -> bool:
	var body := StaticBody3D.new()
	body.name = "EntryBootScraper"
	body.position = SCRAPER_SITE
	if not _mount_stock(body, SCRAPER, SCRAPER_PARTS):
		body.free()
		return false
	root.add_child(body)
	return true


static func mount_stand(body: StaticBody3D) -> bool:
	if not _mount_stock(body, UMBRELLA_STAND, STAND_PARTS):
		return false
	body.set_meta("v2_native_domestic_variant", STAND_VARIANT)
	return true


static func _mount_stock(body: StaticBody3D, scene: PackedScene, names: Array) -> bool:
	var stock := scene.instantiate() as Node3D
	var nodes := stock.find_children("*", "MeshInstance3D", true, false)
	if nodes.size() != names.size():
		stock.free()
		return false
	var seen := {}
	var parts: Array[Dictionary] = []
	for draw: MeshInstance3D in nodes:
		var part_name := str(draw.name)
		var section := draw.get_parent() as Node3D
		if part_name not in names or seen.has(part_name) or section == null \
				or section.get_parent() != stock or draw.mesh == null \
				or draw.mesh.get_surface_count() != 1:
			stock.free()
			return false
		seen[part_name] = true
		var key := part_name.get_slice("__", 1)
		var row: Array = FINISHES[key]
		var material := MatLib.get_mat(row[0]).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(row[1])
		material.normal_scale = float(row[2])
		material.roughness = float(row[3])
		if row.size() == 5:
			material.albedo_color = (row[4] as Color).linear_to_srgb()
		var mesh := draw.mesh.duplicate() as Mesh
		mesh.surface_set_material(0, material)
		draw.mesh = mesh
		draw.set_meta("v2_material_key", row[0])
		draw.set_meta("material_key", key)
		var shape := mesh.create_trimesh_shape()
		if shape == null:
			stock.free()
			return false
		parts.append({"shape": shape, "pose": stock.transform * section.transform * draw.transform})
	stock.name = "NativeStock"
	body.add_child(stock)
	for part in parts:
		var collision := CollisionShape3D.new()
		collision.shape = part.shape
		collision.transform = part.pose
		body.add_child(collision)
	return true

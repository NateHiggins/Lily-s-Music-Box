extends Node
## Qualify newly booted arcade presentation within the V2 composition only.
## Preserve original tint, emission, albedo and software/gameplay owners.
const RECIPES := {
	"board_concrete":"concrete", "sealed_screed":"concrete", "safety_yellow":"indicator_enamel",
	"ceiling_tile":"plaster_stained", "galvanised":"galvanized_roof", "ply_crate":"plywood",
	"strip_light":"milk_glass", "coverall_drill":"fabric_warm", "wire_glass":"milk_glass",
	"graybox_floor":"concrete", "worn_flagstone":"concrete", "mosaic_tesserae":"subway_tile",
	"graybox_ceiling":"plaster_stained", "vault_plaster":"plaster_stained",
	"graybox_wall":"concrete", "cold_ashlar":"concrete", "damp_stain":"plaster_stained",
	"tarnished_gold":"brass_dull", "tarnished_brass":"brass_dull", "decaying_velvet":"fabric_warm",
	"black_iron":"iron_neutral", "graybox_column":"concrete", "graybox_door_frame":"wood_dark",
	"graybox_crate":"wood_dark", "graybox_door":"wood_dark", "oak_timber":"wood_dark",
	"graybox_lamp":"milk_glass", "graybox_window":"milk_glass", "candle_glass":"milk_glass", "candleflame":"milk_glass",
	"graybox_enemy_spawn":"bakelite", "graybox_player_spawn":"bakelite", "graybox_pickup":"bakelite",
	"graybox_weapon":"iron_neutral", "graybox_objective":"paper", "graybox_trigger_volume":"paper", "graybox_ambience_zone":"paper"
}
var _pending: Array[WeakRef] = []
var _queued := false
func _ready() -> void:
	get_tree().node_added.connect(_added)
	for draw: Node in get_parent().find_children("*","MeshInstance3D",true,false): _added(draw)
func _added(node: Node) -> void:
	if not node is MeshInstance3D or not get_parent().is_ancestor_of(node): return
	var owner := node.get_parent()
	while owner != get_parent() and owner.get_script() == null: owner = owner.get_parent()
	if owner.get_script() == null or owner.get_script().resource_path.get_file() not in ["swc_entity.gd","swc_enemy.gd","swc_player.gd"]: return
	_pending.append(weakref(node))
	if not _queued: _queued = true; call_deferred("_flush")
func _flush() -> void:
	_queued = false
	for ref: WeakRef in _pending:
		var draw := ref.get_ref() as MeshInstance3D
		if draw == null or draw.mesh == null: continue
		for index in draw.mesh.get_surface_count():
			var material := draw.get_active_material(index) as StandardMaterial3D
			if material == null: continue
			if not material.resource_name.is_empty() and not RECIPES.has(material.resource_name):
				push_error("Unregistered embedded V2 finish: " + material.resource_name); continue
			var key: String = RECIPES.get(material.resource_name,"bakelite")
			var maps := MatLib.get_mat(key) as StandardMaterial3D
			if material.albedo_texture == null: material.albedo_texture = maps.albedo_texture
			if material.roughness_texture == null: material.roughness_texture = maps.roughness_texture
			if material.normal_texture == null: material.normal_texture = maps.normal_texture
			material.normal_enabled = true; material.normal_scale = .06
			material.uv1_triplanar = false
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			material.set_meta("v2_embedded_stock",key)
	_pending.clear()

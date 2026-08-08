class_name SwcPackage
extends RefCounted

## Loads a compiled World Package and attaches it to an already-playable world.
##
## The binder can only ever *add* nodes under an entity's PresentationAnchor, plus
## tint lights and hand over audio streams. It cannot touch collision, transforms,
## gameplay scripts or the semantic scene, because it is never given them.
##
## No inference, no network, no generation: the package is read from local files
## like any other game asset (spec §20).

var root: String = ""
var source: SwcPackageSource = null
var manifest: Dictionary = {}
var asset_manifest: Dictionary = {}
var bible: Dictionary = {}
var environment_settings: Dictionary = {}
var ui_theme: Dictionary = {}

## What this world puts in the player's hands, from the Bible's `held_object`.
## Empty when a package predates the block, in which case the viewmodel falls
## back to the graybox stub - which is the correct behaviour, not a failure.
var held_object: Dictionary = {}
## Beat text in this world's voice: {"outcome.chose_left": "...", ...}
var narration: Dictionary = {}

var world_id: String = ""
var world_name: String = ""
var build_id: String = ""
var scene_hash: String = ""
var prompt_excerpt: String = ""

var _assets: Dictionary = {}
var _material_cache: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _ambience_players: Array[AudioStreamPlayer3D] = []
var _music_player: AudioStreamPlayer = null

var bound_count: int = 0
var mesh_count: int = 0
var material_only_count: int = 0
var missing_assets: Array[String] = []


## Presentation-API contract version this build implements. A package that needs
## a newer one is refused rather than half-loaded.
const RUNTIME_API := 1


## Load, verify against the scene it claims to dress, and bind - the three steps
## a caller always wants together. Returns null if any of them fails, because a
## half-bound package renders a plausible-looking lie about a level that is not
## there, and graybox is a better answer than that.
static func load_and_bind(package_path: String, entities: Dictionary, scene: SwcScene) -> SwcPackage:
	var package := SwcPackage.load_from(package_path)
	if package == null:
		return null
	if package.scene_hash != "" and scene.scene_hash != "" 			and package.scene_hash != scene.scene_hash:
		push_error(
			"SwcPackage: %s was built against scene %s, not %s"
			% [package_path, package.scene_hash.substr(0, 12), scene.scene_hash.substr(0, 12)]
		)
		return null
	package.bind(entities)
	if not package.missing_assets.is_empty():
		push_warning(
			"SwcPackage: %d unresolved references in %s"
			% [package.missing_assets.size(), package.world_id]
		)
	return package


static func load_from(package_root: String) -> SwcPackage:
	var opened := SwcPackageSource.open(package_root)
	if opened == null:
		return null

	var package := SwcPackage.new()
	package.root = package_root
	package.source = opened

	var manifest: Variant = opened.json("manifest.json")
	if typeof(manifest) != TYPE_DICTIONARY:
		push_error("SwcPackage: no readable manifest.json in %s" % package_root)
		return null
	package.manifest = manifest

	var compatibility: Dictionary = manifest.get("compatibility", {})
	var required_api := int(compatibility.get("runtime_api", 0))
	if required_api > RUNTIME_API:
		push_error(
			"SwcPackage: %s needs runtime API %d but this build implements %d"
			% [package_root, required_api, RUNTIME_API]
		)
		return null

	package.world_id = String(manifest.get("world_id", ""))
	package.world_name = String(manifest.get("world_name", package.world_id))
	package.build_id = String(manifest.get("build_id", ""))
	var source: Dictionary = manifest.get("source", {})
	package.scene_hash = String(source.get("source_gameplay_scene_hash", ""))
	package.prompt_excerpt = String(source.get("prompt_excerpt", ""))

	var entry_points: Dictionary = manifest.get("entry_points", {})
	var asset_manifest: Variant = opened.json(
		String(entry_points.get("asset_manifest", "asset_manifest.json"))
	)
	if typeof(asset_manifest) != TYPE_DICTIONARY:
		push_error("SwcPackage: no readable asset_manifest.json in %s" % package_root)
		return null
	package.asset_manifest = asset_manifest
	for asset_variant in asset_manifest.get("assets", []):
		var asset: Dictionary = asset_variant
		package._assets[String(asset.get("asset_id", ""))] = asset

	var bible: Variant = opened.json(String(entry_points.get("world_bible", "world_bible.json")))
	if typeof(bible) == TYPE_DICTIONARY:
		package.bible = bible
		# The Bible travels inside the package, so the runtime can read the parts
		# of it that are presentation *instructions* rather than compiled assets.
		var held: Variant = (bible as Dictionary).get("held_object", {})
		if typeof(held) == TYPE_DICTIONARY:
			package.held_object = held

	var environment: Variant = opened.json(
		String(entry_points.get("environment", "environment/env_main.json"))
	)
	if typeof(environment) == TYPE_DICTIONARY:
		package.environment_settings = environment

	var theme: Variant = opened.json(String(entry_points.get("ui_theme", "ui/ui_theme.json")))
	if typeof(theme) == TYPE_DICTIONARY:
		package.ui_theme = theme

	# Optional, and absent from every level package. Asking a source for a file it
	# does not have is not an error; only failing to read one it declares is.
	var narration_path := String(entry_points.get("narration", "ui/narration_main.json"))
	if opened.has(narration_path):
		var narration: Variant = opened.json(narration_path)
		if typeof(narration) == TYPE_DICTIONARY:
			package.narration = (narration as Dictionary).get("lines", {})

	return package


# ------------------------------------------------------------------- binding


func bind(entities: Dictionary) -> void:
	bound_count = 0
	mesh_count = 0
	material_only_count = 0
	missing_assets.clear()

	for binding_variant in asset_manifest.get("bindings", []):
		var binding: Dictionary = binding_variant
		var semantic_id := String(binding.get("semantic_id", ""))
		var entity: SwcEntity = entities.get(semantic_id)
		if entity == null:
			# The package references an entity this scene does not have. That is a
			# scene/package mismatch, not something to paper over.
			missing_assets.append("entity:%s" % semantic_id)
			continue
		_bind_one(entity, binding)
		bound_count += 1


func _bind_one(entity: SwcEntity, binding: Dictionary) -> void:
	var materials := {}
	for slot_variant in binding.get("materials", {}):
		var slot := String(slot_variant)
		var material := _material(String(binding["materials"][slot]))
		if material != null:
			materials[slot] = material

	var mesh_asset_id: Variant = binding.get("mesh")
	if mesh_asset_id != null and String(mesh_asset_id) != "":
		_attach_mesh(entity, String(mesh_asset_id), materials, binding)
		mesh_count += 1
	elif not materials.is_empty():
		# A material-only skin reuses the graybox shapes: the entity's freedom did
		# not permit new geometry, so its silhouette is exactly what it always was.
		var primary: Material = materials.get("main", materials.values()[0])
		for instance in SwcGraybox.build_mesh_instances(entity.data, primary):
			entity.presentation_anchor.add_child(instance)
		material_only_count += 1

	_apply_light_override(entity, binding.get("light_override", {}))
	_attach_audio(entity, binding.get("audio", {}))

	var label := String(binding.get("label", ""))
	if not label.is_empty():
		entity.display_label = label


func _attach_mesh(
	entity: SwcEntity, asset_id: String, materials: Dictionary, binding: Dictionary
) -> void:
	var loaded := _mesh(asset_id)
	if loaded.is_empty():
		missing_assets.append(asset_id)
		return

	var instance := MeshInstance3D.new()
	instance.name = "Skin"
	instance.mesh = loaded["mesh"]

	var slots: Array = loaded["slots"]
	for surface_index in range(slots.size()):
		var material: Material = materials.get(String(slots[surface_index]))
		if material == null and not materials.is_empty():
			material = materials.get("main", materials.values()[0])
		if material != null:
			instance.set_surface_override_material(surface_index, material)

	var offset: Array = binding.get("visual_offset", [0, 0, 0])
	instance.position = Vector3(offset[0], offset[1], offset[2])
	instance.rotation_degrees = Vector3(0.0, float(binding.get("visual_yaw_deg", 0.0)), 0.0)
	entity.presentation_anchor.add_child(instance)


func _apply_light_override(entity: SwcEntity, override: Dictionary) -> void:
	var light := entity.get_node_or_null("Light") as OmniLight3D
	if light == null or override.is_empty():
		return
	# Colour and intensity are presentation. Position and the authored base energy
	# are gameplay, so the override scales the base rather than replacing it.
	var base_energy := float(light.get_meta("base_energy", light.light_energy))
	var base_range := float(light.get_meta("base_range", light.omni_range))
	light.light_color = SwcFormats.color_from_hex(
		String(override.get("color", "#ffffff")), Color.WHITE
	)
	light.light_energy = base_energy * float(override.get("energy_scale", 1.0))
	light.omni_range = base_range * float(override.get("range_scale", 1.0))


func _attach_audio(entity: SwcEntity, audio: Dictionary) -> void:
	for event_variant in audio:
		var event := String(event_variant)
		var asset_id := String(audio[event])
		var asset: Dictionary = _assets.get(asset_id, {})
		if asset.is_empty():
			missing_assets.append(asset_id)
			continue
		var looping := event == "loop"
		var stream := SwcFormats.parse_wav(source.read(String(asset["path"])), looping)
		if stream == null:
			missing_assets.append(asset_id)
			continue
		if looping:
			var player := AudioStreamPlayer3D.new()
			player.name = "Ambience"
			player.stream = stream
			player.volume_db = float(entity.param("volume_db", -14.0))
			player.unit_size = 24.0
			player.max_distance = 60.0
			player.autoplay = false
			entity.presentation_anchor.add_child(player)
			_ambience_players.append(player)
		else:
			entity.audio_streams[event] = stream


func _material(asset_id: String) -> Material:
	if _material_cache.has(asset_id):
		return _material_cache[asset_id]
	var asset: Dictionary = _assets.get(asset_id, {})
	if asset.is_empty():
		missing_assets.append(asset_id)
		return null
	var material := SwcFormats.parse_material(
		source.read(String(asset["path"])), String(asset["path"]), source.reader()
	)
	_material_cache[asset_id] = material
	return material


func _mesh(asset_id: String) -> Dictionary:
	if _mesh_cache.has(asset_id):
		return _mesh_cache[asset_id]
	var asset: Dictionary = _assets.get(asset_id, {})
	if asset.is_empty():
		return {}
	var loaded := SwcFormats.parse_mesh(source.read(String(asset["path"])), String(asset["path"]))
	_mesh_cache[asset_id] = loaded
	return loaded


# --------------------------------------------------------------- presentation


func apply_environment(world_environment: WorldEnvironment) -> void:
	var settings := environment_settings
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SwcFormats.color_from_hex(
		String(settings.get("sky_horizon_color", "#101014")), Color(0.06, 0.06, 0.07)
	)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = SwcFormats.color_from_hex(
		String(settings.get("ambient_color", "#202028")), Color(0.12, 0.12, 0.14)
	)
	environment.ambient_light_energy = float(settings.get("ambient_energy", 0.3))

	if bool(settings.get("fog_enabled", false)):
		environment.fog_enabled = true
		environment.fog_light_color = SwcFormats.color_from_hex(
			String(settings.get("fog_color", "#202028")), Color(0.1, 0.1, 0.12)
		)
		environment.fog_density = float(settings.get("fog_density", 0.01))

	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.1
	world_environment.environment = environment


func set_audio_active(active: bool) -> void:
	for player in _ambience_players:
		if not is_instance_valid(player):
			continue
		if active and not player.playing:
			player.play()
		elif not active and player.playing:
			player.stop()
	if _music_player != null and is_instance_valid(_music_player):
		if active and not _music_player.playing:
			_music_player.play()
		elif not active and _music_player.playing:
			_music_player.stop()


func start_music(parent: Node) -> void:
	var asset := _find_asset_of_kind("music")
	if asset.is_empty():
		return
	var stream := SwcFormats.parse_wav(source.read(String(asset["path"])), true)
	if stream == null:
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.stream = stream
	_music_player.volume_db = -16.0
	parent.add_child(_music_player)


func _find_asset_of_kind(kind: String) -> Dictionary:
	for asset_id in _assets:
		var asset: Dictionary = _assets[asset_id]
		if String(asset.get("kind", "")) == kind:
			return asset
	return {}


func unbind(entities: Dictionary) -> void:
	for player in _ambience_players:
		if is_instance_valid(player):
			player.stop()
	_ambience_players.clear()
	if _music_player != null and is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.queue_free()
		_music_player = null
	for semantic_id in entities:
		var entity: SwcEntity = entities[semantic_id]
		entity.clear_presentation()
		var light := entity.get_node_or_null("Light") as OmniLight3D
		if light != null:
			light.light_color = Color(1.0, 0.98, 0.94)
			light.light_energy = float(light.get_meta("base_energy", light.light_energy))
			light.omni_range = float(light.get_meta("base_range", light.omni_range))


## The line this world uses for a narration key, or a visible placeholder. A beat
## that silently showed nothing would look like a bug rather than an ending.
func line(key: String) -> String:
	return String(narration.get(key, ""))


func summary() -> String:
	return (
		"%s  (%s)  %d skinned: %d meshes, %d material-only"
		% [world_name, build_id, bound_count, mesh_count, material_only_count]
	)


func unbound_reasons() -> Array:
	return asset_manifest.get("unbound", [])

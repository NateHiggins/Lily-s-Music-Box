class_name ProjectorProp
extends TVProp
## A 16 mm projector that throws its reel on the room's own wall.
##
## Extends TVProp deliberately rather than replacing it. Everything that already
## talks to a set - BroadcastDirector's `sets` array, the resident routines that
## switch one on and off like a person, and the poltergeist that takes them all -
## speaks a small vocabulary: `powered`, `player_on`, `npc_on`, `possessed`,
## `set_glow`, `interact`. None of that cares whether the picture lands on glass
## or on plaster, so none of it changes. What changes is where the light goes.
##
## The inherited `glass` quad becomes the LENS: a small disc at the front of the
## machine that lights when the lamp is on. `_refresh()` already swaps its
## material on power, so the lens comes on for free.
##
## THE WALL IS FOUND, NOT AUTHORED. The machine casts a ray along its own facing
## and puts the image where that ray lands, sized by how far it travelled - so
## moving a projector in the layout moves its picture, and a machine aimed at a
## bookcase throws its reel on the bookcase. Nothing needs a second coordinate.

## How far along its own facing the machine will look for something to project
## onto. Beyond this it is aimed at nothing and stays dark.
const THROW_MAX := 6.0
## Image height per metre of throw. A short-focus lens in a small room.
const THROW_RATIO := 0.46
## Decay per frame in the plate buffer. Low = long memory = the figures that
## moved during the exposure lose their heads. See ORISON_PROJECTOR_BRIEF 2b.
const PLATE_DECAY := 0.055
const FEED_RES := Vector2i(384, 640)

var reel := ""

var _screen: MeshInstance3D
var _feed: SubViewport
var _accum: SubViewport
var _video: VideoStreamPlayer
var _beam: SpotLight3D


func setup(owner_director: Node, unit_id: String, shared: ShaderMaterial) -> void:
	super.setup(owner_director, unit_id, shared)
	name = "Projector_" + unit_id
	add_to_group("projectors")

	# The inherited glass becomes the lens: small, low, and at the front of the
	# machine rather than a screen the size of a television.
	var lens := QuadMesh.new()
	lens.size = Vector2(0.075, 0.075)
	glass.mesh = lens
	glass.position = Vector3(0.0, 0.30, -0.16)

	# The lamp inside the housing, spilling from the vents. Warm, weak, and
	# nothing like the cold blue a television throws.
	glow.position = Vector3(0.0, 0.32, 0.0)
	glow.omni_range = 2.1

	_build_body()
	_build_feed()
	_build_screen()


## A Kodascope in massing only: lamphouse, lens barrel, and the two arms that
## carry the reels. The detail lives in the silhouette, because in a dark room
## that is all anyone will ever see of it.
func _build_body() -> void:
	var iron := Color(0.10, 0.105, 0.11)
	var brass := Color(0.42, 0.34, 0.16)
	_part(Vector3(0.20, 0.22, 0.30), Vector3(0.0, 0.24, 0.06), iron, 0.42)
	_part(Vector3(0.09, 0.09, 0.14), Vector3(0.0, 0.30, -0.12), brass, 0.30)
	_part(Vector3(0.26, 0.03, 0.20), Vector3(0.0, 0.12, 0.04), iron, 0.55)
	# Reel arms: the upper feed and the lower take-up, which is the shape
	# everyone recognises even when they cannot name the machine.
	for arm in [[0.44, 1.0], [0.20, -1.0]]:
		var y: float = float(arm[0])
		_part(Vector3(0.02, 0.14, 0.02), Vector3(0.0, (y + 0.30) * 0.5, 0.14),
				iron, 0.40)
		var reel_mesh := CylinderMesh.new()
		reel_mesh.top_radius = 0.085
		reel_mesh.bottom_radius = 0.085
		reel_mesh.height = 0.014
		var disc := MeshInstance3D.new()
		disc.mesh = reel_mesh
		disc.rotation_degrees = Vector3(90, 0, 0)
		disc.position = Vector3(0.0, y, 0.14)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.16, 0.15, 0.14)
		mat.roughness = 0.6
		disc.material_override = mat
		add_child(disc)


func _part(size: Vector3, at: Vector3, tint: Color, rough: float) -> void:
	var box := BoxMesh.new()
	box.size = size
	var node := MeshInstance3D.new()
	node.mesh = box
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = rough
	mat.metallic = 0.5
	node.material_override = mat
	add_child(node)


## The film, then the plate. Same construction as ArcadeMachine._build_phosphor()
## with the decay turned right down: a phosphor forgets in milliseconds and an
## exposure forgets in seconds, and that single number is what turns a video into
## a photograph of something that would not hold still.
func _build_feed() -> void:
	_feed = SubViewport.new()
	_feed.size = FEED_RES
	_feed.disable_3d = true
	_feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_feed)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.loop = true
	_video.volume_db = -80.0     # silent film; the mechanism is the sound
	_video.size = Vector2(FEED_RES)
	_feed.add_child(_video)

	_accum = SubViewport.new()
	_accum.size = FEED_RES
	_accum.disable_3d = true
	_accum.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_accum.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_accum)
	var decay := ColorRect.new()
	decay.color = Color(0.0, 0.0, 0.0, PLATE_DECAY)
	decay.size = Vector2(FEED_RES)
	_accum.add_child(decay)
	var live := TextureRect.new()
	live.texture = _feed.get_texture()
	live.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	live.size = Vector2(FEED_RES)
	live.modulate = Color(1, 1, 1, 0.5)
	_accum.add_child(live)


func _build_screen() -> void:
	_screen = MeshInstance3D.new()
	_screen.mesh = QuadMesh.new()
	# A projection is light. It cannot cast a shadow, and fog must not be
	# added to it - an additive quad picks up the environment's fog across its
	# whole area and stamps a hard rectangle on the wall that no aperture can
	# remove. `fog_disabled` in the shader is the other half of that.
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/projected_film.gdshader")
	mat.set_shader_parameter("frame", _accum.get_texture())
	mat.set_shader_parameter("plate", 1.0)
	mat.set_shader_parameter("mono", 1.0)
	mat.set_shader_parameter("aperture_half", Vector2(0.355, 0.400))
	mat.set_shader_parameter("gain", 1.15)
	mat.set_shader_parameter("falloff", 1.05)
	mat.set_shader_parameter("grain_amount", 0.16)
	mat.set_shader_parameter("dust_amount", 0.10)
	_screen.material_override = mat
	_screen.visible = false
	# Parented to the tree root rather than to the machine: the image belongs
	# to the WALL, and a projector that gets nudged should not drag its picture
	# through the plaster.
	add_child(_screen)
	_screen.top_level = true

	_beam = SpotLight3D.new()
	_beam.light_color = Color(1.0, 0.93, 0.78)
	_beam.light_energy = 0.0
	_beam.spot_range = THROW_MAX
	_beam.spot_angle = 14.0
	_beam.shadow_enabled = false
	_beam.position = Vector3(0.0, 0.30, -0.18)
	add_child(_beam)


## Load a reel. Empty id parks the machine dark with nothing threaded.
func load_reel(clip_id: String) -> void:
	reel = clip_id
	if clip_id == "":
		_video.stream = null
		return
	var path := "res://assets/video/clips/%s.ogv" % clip_id
	if not ResourceLoader.exists(path):
		push_warning("ProjectorProp: %s has no reel %s" % [unit, clip_id])
		reel = ""
		return
	_video.stream = load(path)


func interact_prompt() -> String:
	if reel == "":
		return "[E]  No reel threaded"
	return "[E]  " + ("Stop" if powered else "Run") + " the projector"


func _refresh() -> void:
	super._refresh()
	var running := powered and reel != ""
	_feed.render_target_update_mode = (SubViewport.UPDATE_ALWAYS if running
			else SubViewport.UPDATE_DISABLED)
	_accum.render_target_update_mode = _feed.render_target_update_mode
	if running:
		_aim()
		_video.play()
	else:
		_video.stop()
	_screen.visible = running
	_beam.light_energy = 0.55 if running else 0.0


## Find the wall. The machine looks along its own facing and puts the image
## where the ray lands; a projector aimed at nothing stays dark rather than
## hanging a picture in mid-air.
func _aim() -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, 0.30, 0.0)
	var dir := -global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * THROW_MAX)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		_screen.visible = false
		return
	var throw: float = from.distance_to(hit.position)
	var height: float = clampf(throw * THROW_RATIO, 0.5, 2.4)
	(_screen.mesh as QuadMesh).size = Vector2(height * 0.68, height)
	# A hair off the surface, or it z-fights the plaster it is landing on.
	_screen.global_position = hit.position + hit.normal * 0.02
	_screen.global_basis = Basis.looking_at(-hit.normal, Vector3.UP)

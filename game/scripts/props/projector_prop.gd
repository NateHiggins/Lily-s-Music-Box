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
## Reel discs, turned while the film runs.
var _spin: Array[MeshInstance3D] = []


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


## A 16 mm Kodascope, built the way the lamps were: primitives, but enough of
## them that the silhouette is the machine rather than a suggestion of one.
##
## The shape people recognise is three things stacked - a heavy cast foot, a
## squat body with a lens on the front, and two reels on arms above and behind
## it. Everything else is detail nobody will name and everybody would miss.
## It faces local -Z, the same as the beam.
func _build_body() -> void:
	# Crinkle-black enamel over cast iron. Dark, but not the near-black the
	# first pass used - at 0.105 albedo the whole machine disappeared into an
	# unlit room and read as a silhouette with a brass ring on it. Painted iron
	# still catches a highlight, and the highlight is how you read the shape.
	var iron := Color(0.185, 0.190, 0.196)
	var dark := Color(0.130, 0.134, 0.140)
	var brass := Color(0.52, 0.41, 0.19)
	var bake := Color(0.155, 0.130, 0.112)

	# --- the cast foot, on two pads so it sits flat on a table that is not
	_part(Vector3(0.27, 0.026, 0.185), Vector3(0.0, 0.013, 0.02), iron, 0.52)
	for sx in [-0.105, 0.105]:
		_part(Vector3(0.042, 0.014, 0.150), Vector3(sx, 0.007, 0.02), dark, 0.75)
	# The column, not a stalk. At 55 mm across the head looked like a lollipop
	# on a stick; these machines carry their weight on a broad cast pillar.
	_part(Vector3(0.090, 0.115, 0.095), Vector3(0.0, 0.072, 0.045), iron, 0.45)

	# --- the head: mechanism in front, lamphouse behind
	_part(Vector3(0.115, 0.155, 0.115), Vector3(0.0, 0.195, -0.020), iron, 0.40)
	_part(Vector3(0.135, 0.175, 0.130), Vector3(0.0, 0.205, 0.080), dark, 0.38)
	# Vents, and they are where the lamp gets out.
	for i in 6:
		_part(Vector3(0.10, 0.008, 0.004),
				Vector3(0.0, 0.145 + float(i) * 0.024, 0.146), bake, 0.9)
	# The chimney, because the lamp cooked the housing.
	_part(Vector3(0.055, 0.030, 0.055), Vector3(0.0, 0.305, 0.080), dark, 0.5)

	# --- the lens: barrel, focus collar, front bezel. All along the throw.
	_barrel(0.030, 0.075, Vector3(0.0, 0.205, -0.115), dark, 0.35, AXIS_Z)
	_barrel(0.037, 0.020, Vector3(0.0, 0.205, -0.096), brass, 0.28, AXIS_Z)
	_barrel(0.034, 0.014, Vector3(0.0, 0.205, -0.157), dark, 0.30, AXIS_Z)

	# --- the gate and the two rollers the film runs over
	_part(Vector3(0.014, 0.055, 0.030), Vector3(0.062, 0.205, -0.030), brass, 0.35)
	_barrel(0.020, 0.014, Vector3(0.070, 0.255, -0.010), dark, 0.4, AXIS_X)
	_barrel(0.020, 0.014, Vector3(0.070, 0.150, -0.010), dark, 0.4, AXIS_X)

	# --- controls: speed knob, switch, crank stub
	_barrel(0.022, 0.016, Vector3(-0.072, 0.230, -0.010), bake, 0.45, AXIS_X)
	_part(Vector3(0.012, 0.026, 0.010), Vector3(-0.070, 0.160, -0.030), bake, 0.5)
	_barrel(0.010, 0.030, Vector3(-0.082, 0.195, 0.050), dark, 0.4, AXIS_X)

	# --- the reels. Upper feeds, lower takes up.
	_reel_arm(Vector3(0.0, 0.400, 0.045), 0.098)
	_reel_arm(Vector3(0.0, 0.132, 0.152), 0.086)

	# --- cloth-braided flex, the way every appliance in this building leaves
	_barrel(0.005, 0.16, Vector3(0.0, 0.030, 0.135), bake, 0.85, AXIS_Z)


## One reel: strut, spindle, two flanges, and the wound film between them. The
## film is the widest dark band and it is what makes a reel read as loaded.
func _reel_arm(at: Vector3, radius: float) -> void:
	var iron := Color(0.105, 0.108, 0.112)
	var hub := Color(0.14, 0.135, 0.13)
	_strut(Vector3(0.0, 0.275, 0.070), at, 0.011, iron)
	_barrel(0.010, 0.050, at, iron, 0.4, AXIS_X)
	_barrel(radius, 0.004, at + Vector3(-0.018, 0, 0), hub, 0.55, AXIS_X, true)
	_barrel(radius, 0.004, at + Vector3(0.018, 0, 0), hub, 0.55, AXIS_X, true)
	_barrel(radius * 0.80, 0.030, at, Color(0.045, 0.040, 0.038), 0.75, AXIS_X, true)
	_barrel(0.020, 0.040, at, hub, 0.5, AXIS_X, true)


func _part(size: Vector3, at: Vector3, tint: Color, rough: float) -> MeshInstance3D:
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
	return node


## A cylinder with an explicit axis, because CylinderMesh runs along +Y and
## almost nothing on this machine does. AXIS_X is the reel spindle (discs read
## as circles from the side, which is where the player stands), AXIS_Z is the
## lens and the film rollers.
enum { AXIS_Y, AXIS_X, AXIS_Z }


func _barrel(radius: float, height: float, at: Vector3, tint: Color,
		rough: float, axis := AXIS_Y, spins := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	match axis:
		AXIS_X:
			node.rotation_degrees = Vector3(0, 0, 90)
		AXIS_Z:
			node.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = rough
	mat.metallic = 0.55
	node.material_override = mat
	add_child(node)
	if spins:
		_spin.append(node)
	return node


## A strut between two points. Same lesson the articulated lamps taught: a
## CylinderMesh rotates about its own centre, so place it at the midpoint and
## turn its +Y to face the far end rather than guessing a joint position.
func _strut(a: Vector3, b: Vector3, radius: float, tint: Color) -> void:
	var dir := b - a
	var node := _barrel(radius, dir.length(), (a + b) * 0.5, tint, 0.42)
	node.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))


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


## The reels turn while the film runs, and the take-up is the one that matters:
## a projector whose spools are still is a projector nobody threaded.
func _process(delta: float) -> void:
	if not powered or reel == "":
		return
	for disc in _spin:
		disc.rotate_object_local(Vector3.UP, delta * 2.4)

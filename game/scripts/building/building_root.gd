extends Node3D
## Assembles Orison Apartments: instances per-floor glTF scenes, spawns
## functional props from the shared layout markers, places the player and
## elevator, and manages coarse level-of-interest floor visibility (a
## streaming stand-in until a real HLOD pass lands).
##
## There is deliberately no occlusion-culling pass. One existed, built from
## the same wall data as everything else, emitting a box for every solid
## pier, spandrel and header. The boxes were correct and that was the
## problem: each sat exactly coincident with the masonry it described, so
## the facade occluded itself. Headers and spandrels culled their own
## brick, and the street elevation showed dark bands in a grid matching
## the floors and windows - with the window glazing among the things that
## vanished. Removed 2026-08-05 rather than nudged, because an occluder
## offset far enough not to cull its own wall is far enough to pop the
## corridor beyond a doorway instead.

const FLOOR_SCENES := {
	"B1": "res://assets/building/floor_b1.gltf",
	"F01": "res://assets/building/floor_01.gltf",
	"F02": "res://assets/building/floor_02.gltf",
	"F03": "res://assets/building/floor_03.gltf",
	"F04": "res://assets/building/floor_04.gltf",
	"F05": "res://assets/building/floor_05.gltf",
	"F06": "res://assets/building/floor_06.gltf",
	"ROOF": "res://assets/building/roof.gltf",
}
const PROP_SCRIPTS := {
	"radiator": preload("res://scripts/props/radiator_prop.gd"),
	"lamp": preload("res://scripts/props/lamp_prop.gd"),
	"corridor_light": preload("res://scripts/props/corridor_light_prop.gd"),
	"washer": preload("res://scripts/props/washer_prop.gd"),
	"dryer": preload("res://scripts/props/washer_prop.gd"),
	"boiler": preload("res://scripts/props/boiler_prop.gd"),
	"toaster": preload("res://scripts/props/toaster_prop.gd"),
	"fridge": preload("res://scripts/props/fridge_prop.gd"),
	"stove": preload("res://scripts/props/stove_prop.gd"),
	"monitor": preload("res://scripts/props/monitor_prop.gd"),
	"boxfan": preload("res://scripts/props/boxfan_prop.gd"),
	"door_anomaly": preload("res://scripts/props/door_anomaly_prop.gd"),
	"case_door": preload("res://scripts/props/case_door_prop.gd"),
	"speaker": preload("res://scripts/props/speaker_prop.gd"),
	"flue_breast": preload("res://scripts/props/flue_breast_prop.gd"),
	"porch_deck": preload("res://scripts/props/porch_deck_prop.gd"),
	"kettle": preload("res://scripts/props/kettle_prop.gd"),
	"wall_clock": preload("res://scripts/props/clock_prop.gd"),
	"smoke_detector": preload("res://scripts/props/smoke_detector_prop.gd"),
	"exhaust_fan": preload("res://scripts/props/exhaust_fan_prop.gd"),
	"ceiling_light": preload("res://scripts/props/ceiling_light_prop.gd"),
	"pendant_shade": preload("res://scripts/props/light_fixture_prop.gd"),
	"flush_dome": preload("res://scripts/props/light_fixture_prop.gd"),
	"sconce_globe": preload("res://scripts/props/light_fixture_prop.gd"),
	"kitchen_linear": preload("res://scripts/props/light_fixture_prop.gd"),
	"cage_bulb": preload("res://scripts/props/light_fixture_prop.gd"),
	"chandelier": preload("res://scripts/props/light_fixture_prop.gd"),
	"eye_pendant": preload("res://scripts/props/light_fixture_prop.gd"),
	"neon_sign": preload("res://scripts/props/neon_sign_prop.gd"),
	"bodega_signage": preload("res://scripts/props/bodega_signage_prop.gd"),
	"bar_signage": preload("res://scripts/props/harukiya_signage_prop.gd"),
	"sink": preload("res://scripts/props/tap_prop.gd"),
	"shower": preload("res://scripts/props/tap_prop.gd"),
	"mirror": preload("res://scripts/props/medicine_cabinet_prop.gd"),
	"street_lamp": preload("res://scripts/props/light_fixture_prop.gd"),
}
const NPC_RESIDENTS := [
	{"unit": "1A", "name": "Evelyn Marsh", "sprite": "evelyn_marsh"},
	{"unit": "1D", "name": "Teresa Vale", "sprite": "teresa_vale"},
	{"unit": "2A", "name": "Mina Vale", "sprite": "mina_vale"},
	{"unit": "2B", "name": "Lena Ortiz", "sprite": "lena_ortiz"},
	{"unit": "2C", "name": "Juno Kells", "sprite": "juno_kells"},
	{"unit": "3A", "name": "Malcolm Reed", "sprite": "malcolm_reed"},
	{"unit": "3B", "name": "Omar Bell", "sprite": "omar_bell"},
	{"unit": "3D", "name": "Rhea Sato", "sprite": "rhea_sato"},
	{"unit": "4A", "name": "Peter Wren", "sprite": "peter_wren"},
	{"unit": "4C", "name": "Cam Ortiz", "sprite": "cam_ortiz", "slot": -1},
	{"unit": "4C", "name": "Noel Price", "sprite": "noel_price", "slot": 1},
	{"unit": "4D", "name": "Transient Guests", "sprite": "transient_guests"},
	{"unit": "5A", "name": "Nadia Quell", "sprite": "nadia_quell"},
	{"unit": "5B", "name": "Cal Dwyer", "sprite": "cal_dwyer"},
	{"unit": "5C", "name": "Iris Bell", "sprite": "iris_bell"},
	{"unit": "6A", "name": "Sacha Reed", "sprite": "sacha_reed"},
	{"unit": "6B", "name": "Jonah Price", "sprite": "jonah_price"},
	{"unit": "6C", "name": "Mae Kessler", "sprite": "mae_kessler"},
]
## The textured hero meshes are now the active cast. Sprite sheets remain as
## an explicit missing-asset fallback, not as the normal spawn path.
const USE_RIGGED_RESIDENTS := true

var layout: Dictionary = {}
var player: PlayerController
var elevator: OrisonElevator
var call_interface: CallInterface
var light_rig: LightRig
var virus_director: VirusSoundDirector
var floor_nodes: Dictionary = {}
var window_glow: OrisonWindowGlow
var door_glow: OrisonDoorGlow
var broadcast: BroadcastDirector
var resident_routines: ResidentRoutines
var switch_system: SwitchSystem
var moon_fill: MoonFill
var shots: ShotCapture
var heightmaps: HeightmapPass
var warehouse: PropWarehouse
var touch: TouchControls
var phone_carrier: PhoneCarrier
var weather: WeatherFX
var mina_manifestation: MinaCaptionManifestation
var mina_gameplay: MinaCaseGameplay
var portal_rule_display: PortalRuleDisplay
var environment_detail_pass: OrisonDetailPass
var atmospheric_decal_pass: AtmosphericDecalPass
var exterior_detail_pass: ExteriorDetailPass
var found_art_pass: FoundArtPass
var wayfinding_signage: WayfindingSignagePass
var maintenance_headquarters: MaintenanceHeadquarters
var objective_tracker: ObjectiveTracker
var first_shift_director: FirstShiftDirector
var safety_net: SafetyNet
var sanity: SanityDirector
var building_personality: BuildingPersonalityDirector
var intrusions: Intrusions
var fourth_wall: FourthWallLayer
var ambient_soundscape: AmbientSoundscape
var music_director: OrisonMusicDirector
var domestic_witnesses: DomesticWitnessSystem
var affected_prop_count := 0
var reality_controllers: Dictionary = {}
var show_all_floors := false


func _ready() -> void:
	# Findable by group rather than only as the current scene. Systems
	# that need the building reach for this group first and fall back to
	# get_tree().current_scene — a fallback that works in play, where the
	# building IS the scene, and silently fails in every test, where it
	# is a child of the test node. That is how the torch's reaction to
	# intrusions came to be wired to a director it could never find.
	add_to_group("building_root")
	var f := FileAccess.open("res://data/building_layout.json", FileAccess.READ)
	layout = JSON.parse_string(f.get_as_text())
	_build_environment()
	for fid in FLOOR_SCENES:
		var scene := load(FLOOR_SCENES[fid]) as PackedScene
		if scene == null:
			push_warning("missing floor scene %s" % fid)
			continue
		var node := scene.instantiate()
		node.name = fid
		add_child(node)
		floor_nodes[fid] = node
	# Re-attach the height maps the glTF could not carry. Must run after
	# every floor scene is in the tree and before anything else touches
	# their materials.
	heightmaps = HeightmapPass.new()
	add_child(heightmaps)
	heightmaps.build(floor_nodes)
	environment_detail_pass = OrisonDetailPass.new()
	add_child(environment_detail_pass)
	var detail_stats := environment_detail_pass.build(layout, floor_nodes)
	atmospheric_decal_pass = AtmosphericDecalPass.new()
	add_child(atmospheric_decal_pass)
	var atmospheric_decals := atmospheric_decal_pass.build(layout, floor_nodes)
	var railing_polish := OrisonRailingPolish.new()
	add_child(railing_polish)
	var railing_details := railing_polish.build(layout)
	window_glow = OrisonWindowGlow.new()
	window_glow.name = "WindowGlow"
	add_child(window_glow)
	var n_lit := window_glow.build(layout)
	# Corridor-side spill from the closed doors, asking the window pass which
	# rooms are awake so both sides of the same wall tell the same story.
	door_glow = OrisonDoorGlow.new()
	door_glow.name = "DoorGlow"
	add_child(door_glow)
	door_glow.build(layout, window_glow)
	# One video decode feeding every television in the building.
	# The station: per-clip shuffle, live cards, per-set power, one decode.
	broadcast = BroadcastDirector.new()
	broadcast.name = "Broadcast"
	add_child(broadcast)
	broadcast.build(layout, floor_nodes)
	call_interface = CallInterface.new()
	add_child(call_interface)
	# Cases change the building, so the runner needs a handle on it: a
	# `reveal` beat looks its prop up by the same node name the marker
	# pipeline spawned it under. Props are spawned below, and no case can
	# fire before the player has sat down, so the ordering is safe.
	call_interface.world = self
	_spawn_props()
	exterior_detail_pass = ExteriorDetailPass.new()
	add_child(exterior_detail_pass)
	exterior_detail_pass.build(layout, floor_nodes["F01"])
	exterior_detail_pass.configure_street_lights(self)
	_spawn_npc_placeholders()
	# Eighteen people with somewhere to be, and a mesh instead of a sprite
	# for whoever has one yet.
	resident_routines = ResidentRoutines.new()
	resident_routines.name = "ResidentRoutines"
	add_child(resident_routines)
	resident_routines.build(layout,
			get_tree().get_nodes_in_group("resident_placeholders"))
	# The wall switches go live, and the moon keeps switched-off rooms
	# readable instead of void-black.
	switch_system = SwitchSystem.new()
	switch_system.name = "Switches"
	add_child(switch_system)
	switch_system.build(layout, self)
	moon_fill = MoonFill.new()
	moon_fill.name = "MoonFill"
	add_child(moon_fill)
	moon_fill.build(layout, player)
	_spawn_reality_controllers()
	wayfinding_signage = WayfindingSignagePass.new()
	add_child(wayfinding_signage)
	wayfinding_signage.build(self)
	_spawn_reality_affected_props()
	domestic_witnesses = DomesticWitnessSystem.new()
	domestic_witnesses.name = "DomesticWitnessSystem"
	add_child(domestic_witnesses)
	domestic_witnesses.build(layout, floor_nodes)
	# New building, new set of picture hooks. Every subsequent art pass shares
	# this registry so residents, hallway management, and found art cannot
	# unknowingly occupy the same visual patch of wall.
	WallArtLaw.clear_reservations()
	_spawn_character_memory_art()
	_spawn_character_wall_art()
	_spawn_hallway_art()
	_spawn_landing_art()
	found_art_pass = FoundArtPass.new()
	found_art_pass.name = "FoundArtPass"
	add_child(found_art_pass)
	found_art_pass.build(layout, floor_nodes)
	_build_front_entry_details()
	_build_original_orison_ad_board()
	maintenance_headquarters = MaintenanceHeadquarters.new()
	floor_nodes["F01"].add_child(maintenance_headquarters)
	objective_tracker = ObjectiveTracker.new()
	objective_tracker.name = "ObjectiveTracker"
	add_child(objective_tracker)
	mina_manifestation = MinaCaptionManifestation.new()
	mina_manifestation.name = "MinaCaptionManifestation"
	mina_manifestation.setup(self)
	add_child(mina_manifestation)
	mina_gameplay = MinaCaseGameplay.new()
	mina_gameplay.name = "MinaCaseGameplay"
	mina_gameplay.setup(objective_tracker)
	add_child(mina_gameplay)
	portal_rule_display = PortalRuleDisplay.new()
	# East wall of F04 west storage, inset and facing west into the room.
	portal_rule_display.position = GameBoot.b2g([-5.615, 1.10, 11.25])
	portal_rule_display.rotation.y = -PI * 0.5
	add_child(portal_rule_display)
	# The map distortion lab is gone (2026-08-06). It captured every
	# MeshInstance3D on the player's floor and drove their global
	# transforms - walls, floors, ceilings - while the StaticBody3D
	# collision those meshes came with stayed exactly where it was. So
	# the floor you could see moved and the floor you were standing on
	# did not, which is not a haunting, it is the player falling through
	# the world. A poltergeist may move a prop; it may not move the
	# building.
	light_rig = LightRig.new()
	add_child(light_rig)
	if GameBoot.launch_mode == GameBoot.LaunchMode.CINEMATIC \
			and int(GameBoot.settings.get("quality", 0)) == 0:
		# Maximum GL Compatibility profile. Sixteen is the renderer's actual
		# per-object ceiling, so requesting more would only reshuffle winners.
		light_rig.set_budgets(16, 16)
	else:
		# Known-safe development profile retained from the live debug controls.
		light_rig.set_budgets(14, 8)
	elevator = OrisonElevator.new()
	add_child(elevator)
	elevator.setup(layout["elevator"])
	resident_routines.bind_elevator(elevator)
	# The archetype timetables, driving the routines off the same clock
	# the sky reads. Inert under DAYNIGHT=0 so the tests' canonical 03:00
	# building keeps its exact pre-schedule behaviour.
	var schedule_director := ScheduleDirector.new()
	schedule_director.name = "ScheduleDirector"
	add_child(schedule_director)
	schedule_director.setup(resident_routines, layout)
	# The bar keeps hours on the same clock: OPEN / AFTER-HOURS / CLOSED.
	var harukiya_states := HarukiyaStateDirector.new()
	harukiya_states.name = "HarukiyaStateDirector"
	add_child(harukiya_states)
	harukiya_states.setup(self)
	# And gains its hands-on layer: pictures, barrels, pool table, seats.
	var harukiya_hands := HarukiyaInteractables.new()
	harukiya_hands.name = "HarukiyaInteractables"
	add_child(harukiya_hands)
	harukiya_hands.build(self)
	player = PlayerController.new()
	player.position = GameBoot.b2g([0.0, -9.0, 0.1])  # vestibule
	add_child(player)
	# The handset, in the hand that was already carrying the torch.
	# Parented to the camera, so it needs the player in the tree first.
	phone_carrier = PhoneCarrier.new()
	phone_carrier.name = "PhoneCarrier"
	phone_carrier.setup(player, player.camera)
	player.phone_carrier = phone_carrier
	ambient_soundscape = AmbientSoundscape.new()
	ambient_soundscape.setup(player)
	add_child(ambient_soundscape)
	music_director = OrisonMusicDirector.new()
	music_director.setup(self)
	add_child(music_director)
	virus_director = VirusSoundDirector.new()
	add_child(virus_director)
	virus_director.setup(self)
	first_shift_director = FirstShiftDirector.new()
	first_shift_director.name = "FirstShiftDirector"
	first_shift_director.setup(self, objective_tracker, virus_director)
	add_child(first_shift_director)
	var room0 := Room0.new()
	add_child(room0)
	var anomaly: DoorAnomalyProp = get_node_or_null("F04_B_DOOR_ANOMALY")
	if anomaly:
		anomaly.room0 = room0
	# The world is allowed to lie about its own floor — chaos mode, reality
	# thresholds, room-local gravity, furniture moving under the player. The
	# net is what makes all of that safe to ship: it silently remembers the
	# last real standing position and puts the player back if they leave the
	# world. Created before the haunting that can cause the fall.
	safety_net = SafetyNet.new()
	safety_net.name = "SafetyNet"
	safety_net.setup(player)
	add_child(safety_net)
	# The sanity system: an invisible pressure model, eighteen poltergeists
	# built from the residents' own traumas, and a meta layer that breaks the
	# frame. There is no meter and there must never be one — see
	# sanity_director.gd for why.
	fourth_wall = FourthWallLayer.new()
	fourth_wall.name = "FourthWall"
	add_child(fourth_wall)
	intrusions = Intrusions.new()
	intrusions.name = "Intrusions"
	add_child(intrusions)
	intrusions.setup(self, player, fourth_wall)
	sanity = SanityDirector.new()
	sanity.name = "SanityDirector"
	add_child(sanity)
	sanity.setup(self, player, intrusions, fourth_wall)
	building_personality = BuildingPersonalityDirector.new()
	building_personality.name = "BuildingPersonalityDirector"
	add_child(building_personality)
	building_personality.setup(self, player, intrusions)
	sanity.bind_personality(building_personality)
	domestic_witnesses.bind_director(sanity, player)
	ambient_soundscape.bind_sanity(sanity)
	weather = WeatherFX.new()
	weather.name = "WeatherFX"
	weather.setup(player)
	add_child(weather)
	weather.build_reflections(layout)
	touch = TouchControls.new()
	touch.name = "TouchControls"
	add_child(touch)
	touch.look_delta.connect(player.apply_look)
	player.touch_input = touch.enabled
	# Always present, debug launch or not: F is how a shot gets taken and
	# a review tool that only exists in one launch mode is one you have to
	# remember the state of.
	shots = ShotCapture.new()
	shots.name = "ShotCapture"
	add_child(shots)
	if GameBoot.launch_mode == GameBoot.LaunchMode.DEBUG:
		# One of every prop, lit and labelled, 400 m east. Unreachable by
		# design and built in debug launches only, so play never pays for
		# it. See prop_warehouse.gd for why it exists.
		warehouse = PropWarehouse.new()
		add_child(warehouse)
		warehouse.build(PROP_SCRIPTS)
		if safety_net:
			safety_net.exempt_zones.append(warehouse.hall_aabb())
		var debug := preload("res://scripts/ui/building_debug.gd").new()
		debug.setup(self)
		var layer := CanvasLayer.new()
		layer.layer = 10
		add_child(layer)
		layer.add_child(debug)
		shots.chrome = layer
	print("[BUILDING] Orison assembled: %d floors, "
			% [floor_nodes.size()] +
			"%d windows lit, %d railing details, player in lobby"
			% [n_lit, railing_details])
	print("[BUILDING] %d low-overhead environment details and %d story decals"
			% [detail_stats.details, detail_stats.decals])
	print("[BUILDING] %d atmospheric evidence decals" % atmospheric_decals)


func _build_environment() -> void:
	## Tuned for the fixture pools: lower flat ambient so tungsten pools
	## own the rooms, gentle depth fog for aerial perspective down long
	## corridors and the atrium eye, soft glow so emissive envelopes and
	## halos bloom the way bright sources do to a dark-adapted eye.
	var env := Environment.new()
	var panorama := load(
			"res://assets/building/textures/sky/" +
			"orison_queens_night_half_dome_4k.png") as Texture2D
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Target look: moonlit. Shadows read as midnight BLUE, not black —
	# a cool saturated floor under everything, so the tungsten pools and
	# the phone torch both land as warm/cold contrast against it instead
	# of against a void. Deep enough to keep the pools' authority.
	env.ambient_light_color = Color(0.17, 0.23, 0.42)
	env.ambient_light_energy = 0.08
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.10)
	env.fog_density = 0.014
	env.glow_enabled = true
	env.glow_intensity = 0.68
	env.glow_bloom = 0.10
	# Fixtures emit around 1.0-1.2 after grading, so a 1.28 threshold
	# meant no source in the building ever bloomed. Below their output,
	# and the bulbs finally have haloes.
	env.glow_hdr_threshold = 0.85
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	_build_sky_dome(panorama)
	_build_atrium_atmosphere()
	var moon := DirectionalLight3D.new()
	moon.name = "ExteriorMoon"
	moon.light_color = Color(0.65, 0.7, 0.9)
	moon.light_energy = 0.052
	moon.rotation_degrees = Vector3(-38, 30, 0)
	moon.shadow_enabled = true
	moon.shadow_bias = 0.035
	moon.shadow_normal_bias = 0.55
	moon.directional_shadow_max_distance = 48.0
	moon.directional_shadow_fade_start = 0.80
	add_child(moon)
	var director := DayNightDirector.new()
	director.name = "DayNightDirector"
	add_child(director)
	var dome := get_node_or_null("NightSkyHalfDome") as MeshInstance3D
	director.setup(self, env, moon,
			dome.material_override if dome else null)


func _build_sky_dome(panorama: Texture2D) -> void:
	## PanoramaSkyMaterial is unreliable on the Compatibility backend used
	## by this project. This camera-centered upper-hemisphere projection
	## keeps the horizon stable from street to roof and never samples a
	## lower hemisphere. Its quiet zenith band hides polar convergence.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled,
		shadows_disabled;
uniform sampler2D panorama : source_color, filter_linear_mipmap,
		repeat_enable;
uniform vec3 tint = vec3(1.0);
uniform float exposure = 0.76;
void fragment() {
	vec3 direction = normalize(
			(INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	float u = atan(direction.z, direction.x) / (2.0 * PI) + 0.5;
	// Half-dome source: top edge is zenith; bottom edge is horizon.
	// Views below the horizon hold on that final skyline texel instead of
	// exposing the dome's lower half. Fade that edge into distance haze
	// immediately so skyline pixels never stretch into vertical bars.
	float elevation = asin(clamp(direction.y, 0.0, 1.0));
	float v = 1.0 - elevation / (0.5 * PI);
	vec3 color = texture(panorama, vec2(u, v)).rgb * exposure * tint;
	if (direction.y < 0.0) {
		float haze = smoothstep(0.0, 0.025, -direction.y);
		color = mix(color, vec3(0.018, 0.025, 0.040), haze);
	}
	ALBEDO = color;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("panorama", panorama)
	var sphere := SphereMesh.new()
	sphere.radius = 120.0
	sphere.height = 240.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var dome := MeshInstance3D.new()
	dome.name = "NightSkyHalfDome"
	dome.mesh = sphere
	dome.material_override = material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)


## The atrium eye under its skylight earns the money atmosphere: a faked
## volumetric shaft (additive gradient cone, no volumetrics on the
## Compatibility backend), slow dust motes riding it, and a soft
## vignette that pulls every frame toward the lens.
func _build_atrium_atmosphere() -> void:
	# The court's eye is a 2.92 m SQUARE — the stair wraps it with 1.70 m
	# flights on the east and west and landings north and south. A round
	# cone in a square well spilled through the balustrades at the corners
	# and stopped short of both ends. This is a square prism matched to the
	# eye, running from the skylight glazing down to the lobby floor, so
	# the light arrives from where the glass actually is.
	var shaft := MeshInstance3D.new()
	shaft.name = "AtriumShaft"
	var prism := BoxMesh.new()
	var top := 21.35            # underside of the monitor's skylight
	var bottom := -2.6          # basement floor, where the stair starts
	prism.size = Vector3(2.86, top - bottom, 2.86)
	shaft.mesh = prism
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# You STAND INSIDE this thing — it fills the eye you are looking up. So
	# render the far wall only (CULL_FRONT drops the faces between you and
	# the middle of the volume). With both faces additive, every sightline
	# crossed two of them and the whole frame washed to white.
	sm.cull_mode = BaseMaterial3D.CULL_FRONT
	sm.no_depth_test = false
	# A gradient texture cannot do this: a box's UVs restart per face, so
	# "bright toward the skylight" would repeat six times.
	#
	# The dimming lives in the COLOUR, not the alpha. Additive blending adds
	# albedo.rgb, and leaning on a low alpha to hold it back did not work —
	# the volume came through at nearly full strength and washed the court
	# white with a hard box edge across the stair. A near-black colour adds
	# a near-nothing amount no matter how the blend treats alpha.
	sm.albedo_color = Color(0.055, 0.062, 0.082, 1.0)
	shaft.material_override = sm
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.position = Vector3(0.0, (top + bottom) * 0.5, 0.0)
	add_child(shaft)
	# The source itself: a soft pool right under the skylight glazing, so
	# the shaft visibly begins AT the glass instead of merely existing.
	var mouth := MeshInstance3D.new()
	mouth.name = "AtriumSkylightPool"
	var mq := QuadMesh.new()
	mq.size = Vector2(2.86, 2.86)
	mouth.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mg := Gradient.new()
	mg.set_color(0, Color(0.30, 0.33, 0.42, 1.0))
	mg.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var mt := GradientTexture2D.new()
	mt.gradient = mg
	mt.fill = GradientTexture2D.FILL_RADIAL
	mt.fill_from = Vector2(0.5, 0.5)
	mt.fill_to = Vector2(0.5, 0.0)
	mm.albedo_texture = mt
	mouth.material_override = mm
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mouth.position = Vector3(0.0, top - 0.06, 0.0)
	mouth.rotation_degrees = Vector3(90, 0, 0)
	add_child(mouth)
	var dust := CPUParticles3D.new()
	dust.name = "AtriumDust"
	dust.amount = 110
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(2.4, 10.2, 2.4)
	dust.gravity = Vector3(0, -0.015, 0)
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.06
	dust.direction = Vector3(0, -1, 0)
	dust.spread = 180.0
	var dq := QuadMesh.new()
	dq.size = Vector2(0.02, 0.02)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.albedo_color = Color(0.95, 0.92, 0.85, 0.30)
	dq.material = dm
	dust.mesh = dq
	dust.position = Vector3(0.0, 10.4, 0.0)
	add_child(dust)
	var vg_layer := CanvasLayer.new()
	vg_layer.layer = 6
	add_child(vg_layer)
	var vg := TextureRect.new()
	vg.name = "Vignette"
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vgrad := Gradient.new()
	vgrad.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	vgrad.colors = PackedColorArray([
			Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0),
			Color(0, 0, 0, 0.26)])
	var vt := GradientTexture2D.new()
	vt.gradient = vgrad
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(0.5, 0.0)
	vt.width = 512
	vt.height = 512
	vg.texture = vt
	vg_layer.add_child(vg)


func _spawn_props() -> void:
	var count := 0
	for fl in layout["floors"]:
		for m in fl["markers"]:
			if m["kind"] == "desk_zone":
				var desk := DeskZone.new()
				desk.call_interface = call_interface
				# Named like every other marker-spawned node, so the desk
				# can be found by id the way the props can.
				desk.name = m["id"]
				add_child(desk)
				desk.global_position = GameBoot.b2g(m["pos"])
				continue
			if m["kind"] == "door":
				var door: DoorProp = LandmarkEntryDoor.new() \
						if str(m["id"]) == "F01_DOOR_06" else DoorProp.new()
				door.width = float(m["w"])
				door.height = float(m["h"])
				door.leaf_state = m["leaf"]
				door.swing_out = String(m.get("swing", "")) == "out"
				door.name = m["id"]
				# transform BEFORE add_child: a sync_to_physics leaf keeps
				# its global transform if the parent moves after entry
				door.position = GameBoot.b2g(m["pos"])
				door.rotation.y = deg_to_rad(-float(m.get("yaw_deg", 0)))
				add_child(door)
				continue
			var script: GDScript = PROP_SCRIPTS.get(m["kind"])
			if script == null:
				continue
			var prop: FunctionalProp = script.new()
			prop.prop_type = m["kind"]
			prop.name = m["id"]
			if m.has("range") and prop is LightFixtureProp:
				prop.range_clamp = float(m["range"])
			if m.has("energy") and prop is LightFixtureProp:
				prop.energy_scale = float(m["energy"])
			if m.has("standby"):
				prop.set("standby_scale", float(m["standby"]))
			if m.get("navigation", false):
				prop.set("navigation_light", true)
			# The refrigerator needs to know whose kitchen it is, so its
			# contents are somebody's, and whether it is one of the four
			# 1927 monitor-tops, whose door is a different size.
			# A tap needs to know whether it is over a basin or in a
			# stall: same prop, different handles and a different drop.
			if prop is MedicineCabinetProp:
				prop.unit = String(m.get("unit", ""))
			if prop is SpeakerProp and m.has("bed"):
				# An ambience bed named in DATA: the bodega radio murmurs
				# because its marker says so, not because the prop grew a
				# special case for one shop.
				prop.bed = String(m["bed"])
			if prop is TapProp:
				prop.fixture = String(m["kind"])
			if prop is FridgeProp:
				prop.unit = String(m.get("unit", ""))
				prop.monitor_top = bool(m.get("monitor", false))
			# A fitting under the entrance marquee hangs off the facade,
			# not off a storey ceiling. Carried through as a group so the
			# "too low for its floor" audit can tell the difference
			# between a canopy lamp and one that punched through a slab.
			if m.get("exterior", false):
				prop.add_to_group("exterior_fixtures")
			if prop is NeonSignProp:
				prop.sign_text = String(m.get("text", "ORISON"))
				prop.vertical = bool(m.get("vertical", true))
				var t: Array = m.get("tint", [1.0, 0.3, 0.42])
				prop.tint = Color(float(t[0]), float(t[1]), float(t[2]))
			if AcousticGraphData.nodes.has(m["id"]):
				prop.graph_node_id = m["id"]  # bound to the shared graph
			# Compatibility renderer light transforms must be authored before
			# _ready() creates the Light3D children. Moving the prop afterward
			# moved its mesh but left the rendered light pool at the origin.
			prop.position = GameBoot.b2g(m["pos"])
			prop.rotation.y = deg_to_rad(-float(m.get("yaw_deg", 0)))
			add_child(prop)
			count += 1
	print("[BUILDING] %d functional props spawned" % count)



## The seven half-landings. They are not rooms - they are stair parts -
## so they cannot go through the hallway-art path, which hangs by room
## id. Each piece rides the north wall of the well at eye height above
## its own landing deck, facing south into the turn, which is the one
## wall a climber faces squarely twice per storey.
func _spawn_landing_art() -> void:
	var file := FileAccess.open("res://data/stair_landing_art.json",
			FileAccess.READ)
	if file == null:
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	var stairs: Array = layout.get("stairs", [])
	if stairs.is_empty():
		return
	var well: Array = stairs[0]["well"]
	var north := float(well[3])
	var count := 0
	for spec in catalog.get("pieces", []):
		var lz := float(spec["landing_z"])
		var art := CharacterMemoryArt.new()
		art.setup({
			"id": spec.id, "atlas": catalog.atlas,
			"col": spec.col, "row": spec.row,
			"cols": catalog.get("cols", 3), "rows": catalog.get("rows", 3),
			"medium": spec.get("medium", "print"),
			"width": spec.get("width", 0.58),
			"height": spec.get("height", 0.58),
			"collection": "hallway_art",
		})
		add_child(art)
		# 6 cm off the plaster, centred on the well, 1.5 m above the deck
		art.global_position = GameBoot.b2g([0.0, north - 0.155, lz + 1.50])
		art.rotation.y = PI
		count += 1
	print("[BUILDING] %d stair-landing pieces hung" % count)

func _spawn_npc_placeholders() -> void:
	var count := 0
	var animated_count := 0
	for spec in NPC_RESIDENTS:
		var unit: String = spec.unit
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") != unit:
				continue
			if candidate.get("kind", "") == "living" \
					or str(candidate.id).ends_with("_MAIN"):
				room = candidate
				break
		if room.is_empty():
			# Studios without a MAIN tag still receive the largest unit room.
			var best_area := -1.0
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") != unit:
					continue
				var rect: Array = candidate.rect
				var area := (float(rect[2]) - float(rect[0])) \
						* (float(rect[3]) - float(rect[1]))
				if area > best_area:
					best_area = area
					room = candidate
		if room.is_empty():
			continue
		var rect: Array = room.rect
		var slot: float = float(spec.get("slot", 0))
		var x := lerpf(float(rect[0]), float(rect[2]), 0.52) + slot * 0.48
		var y := lerpf(float(rect[1]), float(rect[3]), 0.58)
		var npc: Node3D
		var model_path := "res://assets/characters/%s/%s.gltf" % [
				spec.sprite, spec.sprite]
		if not ResourceLoader.exists(model_path):
			model_path = "res://assets/characters/%s/%s_rigged.glb" % [
					spec.sprite, spec.sprite]
		if USE_RIGGED_RESIDENTS and ResourceLoader.exists(model_path):
			var animated := AnimatedResident.new()
			animated.setup(spec.name, spec.sprite, unit, model_path)
			npc = animated
			animated_count += 1
		else:
			var placeholder := NPCPlaceholder.new()
			placeholder.setup(spec.name,
					"res://assets/npcs/%s.png" % spec.sprite,
					spec.sprite, unit)
			npc = placeholder
		npc.position = GameBoot.b2g([x, y, float(floor_data.z) + 0.03])
		var parent: Node = floor_nodes.get(floor_id, self)
		parent.add_child(npc)
		count += 1
	print("[BUILDING] %d residents spawned (%d rigged, %d sprite fallbacks)" %
			[count, animated_count, count - animated_count])


func _spawn_reality_affected_props() -> void:
	var file := FileAccess.open(
			"res://data/reality_affected_props.json", FileAccess.READ)
	if file == null:
		push_warning("reality affected-prop catalog missing")
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	affected_prop_count = 0
	var catalog_ids := {}
	for cluster in catalog.get("case_clusters", []):
		var unit: String = cluster.unit
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") == unit \
					and candidate.get("kind", "") == "living":
				room = candidate
				break
		if room.is_empty():
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") == unit \
						and str(candidate.id).ends_with("_MAIN"):
					room = candidate
					break
		if room.is_empty():
			continue
		var rect: Array = room.rect
		for spec in cluster.props:
			if catalog_ids.has(spec.id):
				push_error("duplicate reality-affected prop id: " + spec.id)
				continue
			catalog_ids[spec.id] = true
			var prop := RealityAffectedProp.new()
			prop.setup(spec.id, spec.name, spec.kind, cluster.case_id)
			var x := lerpf(float(rect[0]), float(rect[2]), float(spec.u))
			var y := lerpf(float(rect[1]), float(rect[3]), float(spec.v))
			var height := 0.80 if spec.get("surface", "floor") == "table" \
					else 0.04
			prop.position = GameBoot.b2g(
					[x, y, float(floor_data.z) + height])
			floor_nodes[floor_id].add_child(prop)
			if reality_controllers.has(cluster.case_id):
				reality_controllers[cluster.case_id].register_node(prop)
			affected_prop_count += 1
	for spec in catalog.get("shared_props", []):
		if catalog_ids.has(spec.id):
			push_error("duplicate reality-affected prop id: " + spec.id)
			continue
		catalog_ids[spec.id] = true
		var prop := RealityAffectedProp.new()
		prop.setup(spec.id, spec.name, spec.kind)
		prop.position = GameBoot.b2g(spec.position)
		var floor_id: String = spec.get("floor", "F01")
		floor_nodes.get(floor_id, self).add_child(prop)
		affected_prop_count += 1
	var expected_count := int(catalog.get("expected_prop_count",
			affected_prop_count))
	if affected_prop_count != expected_count:
		push_error("reality-affected prop placement mismatch: expected %d, placed %d"
				% [expected_count, affected_prop_count])
	print("[BUILDING] %d reality-affected props placed" %
			affected_prop_count)


func _spawn_reality_controllers() -> void:
	for case_id in RealityCases.definitions:
		var definition: Dictionary = RealityCases.definition(case_id)
		var unit: String = definition.get("unit", "")
		if unit.length() < 2:
			continue
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") == unit \
					and candidate.get("kind", "") == "living":
				room = candidate
				break
		if room.is_empty():
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") == unit \
						and str(candidate.id).ends_with("_MAIN"):
					room = candidate
					break
		if room.is_empty():
			continue
		var rect: Array = room.rect
		var corner_a := GameBoot.b2g(
				[float(rect[0]), float(rect[1]), float(floor_data.z)])
		var corner_b := GameBoot.b2g(
				[float(rect[2]), float(rect[3]), float(floor_data.z) + 3.0])
		var bounds_min := Vector3(
				minf(corner_a.x, corner_b.x),
				minf(corner_a.y, corner_b.y),
				minf(corner_a.z, corner_b.z))
		var bounds_max := Vector3(
				maxf(corner_a.x, corner_b.x),
				maxf(corner_a.y, corner_b.y),
				maxf(corner_a.z, corner_b.z))
		var controller := ApartmentRealityController.new()
		controller.setup(case_id, unit, bounds_min, bounds_max)
		floor_nodes[floor_id].add_child(controller)
		reality_controllers[case_id] = controller
	print("[BUILDING] %d apartment reality controllers ready" %
			reality_controllers.size())


func _spawn_character_memory_art() -> void:
	_spawn_character_art_catalog(
			"res://data/character_memory_art.json",
			"character memory-art", "character memory artworks")


func _spawn_character_wall_art() -> void:
	_spawn_character_art_catalog(
			"res://data/character_wall_art.json",
			"character wall-art", "character-specific wall artworks",
			"character_wall_art")


func _spawn_hallway_art() -> void:
	var file := FileAccess.open("res://data/hallway_art.json", FileAccess.READ)
	if file == null:
		push_warning("hallway-art catalog missing")
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	var count := 0
	for spec in catalog.get("pieces", []):
		var floor_id: String = spec.floor
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty() or not floor_nodes.has(floor_id):
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.id == spec.room:
				room = candidate
				break
		if room.is_empty():
			continue
		spec["collection"] = "hallway_art"
		var art := CharacterMemoryArt.new()
		art.setup(spec)
		var spot := _legal_art_spot(floor_data, room,
				str(spec.get("wall", "north")),
				float(spec.get("along", 0.5)),
				float(spec.get("height", 1.52)))
		if not spot.ok:
			push_warning("no legal wall for hallway piece %s"
					% spec.get("id", "?"))
			art.queue_free()
			continue
		art.position = GameBoot.b2g([
				spot.x, spot.y, float(floor_data.z) + float(spot.height)])
		art.rotation.y = spot.yaw
		floor_nodes[floor_id].add_child(art)
		count += 1
	var expected := int(catalog.get("expected_count", count))
	if count != expected:
		push_error("hallway-art mismatch: expected %d, placed %d"
				% [expected, count])
	print("[BUILDING] %d hallway artworks placed" % count)


func _build_front_entry_details() -> void:
	# Main street door is F01_DOOR_06 at Blender y=-9.795. Both pieces sit
	# beyond the south facade and face the sidewalk.
	# The door's sconce is authored in gen_layout as F01_ENTRY_SCONCE, not
	# built here. A fixture spawned outside the marker pipeline is invisible
	# to the generator's fixture manifest, which then reports one fewer
	# light than the building actually has — and that manifest is what the
	# lighting audit checks itself against.
	var entry_sign := BuildingEntrySign.new()
	entry_sign.position = GameBoot.b2g([0.72, -9.905, 1.58])
	add_child(entry_sign)
	# The marquee's structure ships in floor_01.gltf; its lamps and its
	# name panel cannot. Same origin as the Blender assembly - the facade
	# face at the door centreline - so the two stay welded together.
	# The building's notice board, on the left of the walk from the street
	# door to the stairs, facing east into the route.
	var notices := LobbyBulletinBoard.new()
	# Clear of the dado. At 1.52 the board's lower third sat on the
	# beadboard and the rail ran straight through it; a notice board is
	# hung on the wall above the panelling, never across it.
	notices.position = GameBoot.b2g([-3.14, -5.00, 1.80])
	notices.rotation.y = PI * 0.5
	floor_nodes["F01"].add_child(notices)
	var marquee := EntranceMarqueeDress.new()
	marquee.position = GameBoot.b2g([0.0, -10.00, 0.0])
	add_child(marquee)
	# Cellar light up through the pavement prisms. Origins and panel sizes
	# match the vault_lights assemblies in gen_layout exactly; if one moves
	# the other has to move with it.
	for spec in [[-2.60, -10.72, 2.60, 1.15], [4.10, -10.72, 1.85, 1.15]]:
		var vault := VaultLightGlow.new()
		vault.panel_w = spec[2]
		vault.panel_d = spec[3]
		vault.position = GameBoot.b2g([spec[0], spec[1], 0.052])
		add_child(vault)
	print("[BUILDING] front-door exterior light and signage placed")


func _build_original_orison_ad_board() -> void:
	# Moved off the east wall 2026-08-05. It was hung at y -8.40 and the
	# mail bank sits at -8.85: at 1.42 m wide against the bank's 1.58 m,
	# the board buried 1.05 m of the boxes and stood 70 mm proud of them,
	# so the mail corner read as a frame with some cardboard behind it.
	# The lobby's east run has only 1.13 m clear beside the bank, which
	# the board does not fit into — so it changes walls rather than slides.
	#
	# The west run is 2.72 m of unbroken plaster (its only door is five
	# metres north) and it is the left-hand side of the walk from the
	# street door to the stairs, which is where a notice board belongs.
	# Centred at -8.29 it hangs directly opposite the lobby chandelier,
	# clears the south-wall radiator (which ends at y -9.2) by 200 mm,
	# and still owns the view immediately after the front door.
	var board := LobbyOrisonAdBoard.new()
	board.position = GameBoot.b2g([-5.17, -8.29, 1.52])
	board.rotation.y = PI * 0.5
	floor_nodes["F01"].add_child(board)


func _spawn_character_art_catalog(path: String, error_label: String,
		report_label: String, collection := "character_memories") -> void:
	var file := FileAccess.open(
			path, FileAccess.READ)
	if file == null:
		push_warning(error_label + " catalog missing")
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	var count := 0
	for spec in catalog.get("pieces", []):
		spec["collection"] = collection
		var unit: String = spec.unit
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") == unit \
					and candidate.get("kind", "") == "living":
				room = candidate
				break
		if room.is_empty():
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") == unit \
						and str(candidate.id).ends_with("_MAIN"):
					room = candidate
					break
		if room.is_empty():
			continue
		var rect: Array = room.rect
		var art := CharacterMemoryArt.new()
		art.setup(spec)
		if spec.get("placement", "wall") == "tabletop":
			var wanted_x := lerpf(float(rect[0]), float(rect[2]),
					float(spec.get("u", 0.5)))
			var wanted_y := lerpf(float(rect[1]), float(rect[3]),
					float(spec.get("v", 0.5)))
			var surface := _nearest_art_surface(floor_data, room,
					Vector2(wanted_x, wanted_y))
			var x: float = surface.x
			var y: float = surface.y
			art.position = GameBoot.b2g(
					[x, y, float(floor_data.z) + float(surface.height)])
			art.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
		else:
			# The character chose the wall; the legality pass chooses the
			# exact hook — real wall behind, no opening through it, no
			# tall furniture against it — sliding along before conceding
			# a different wall. Pieces with nowhere legal are not hung.
			var spot := _legal_art_spot(floor_data, room,
					str(spec.get("wall", "north")),
					float(spec.get("along", 0.5)),
					float(spec.get("height", 1.52)))
			if not spot.ok:
				push_warning("no legal wall for %s in %s"
						% [spec.get("id", "?"), unit])
				art.queue_free()
				continue
			art.position = GameBoot.b2g(
					[spot.x, spot.y, float(floor_data.z) +
					float(spot.height)])
			art.rotation.y = spot.yaw
		floor_nodes[floor_id].add_child(art)
		count += 1
	var expected := int(catalog.get("expected_count", count))
	if count != expected:
		push_error("%s mismatch: expected %d, placed %d"
				% [error_label, expected, count])
	print("[BUILDING] %d %s placed" % [count, report_label])


## The old tabletop portraits were suspended at z=.82 wherever their u/v
## landed. Choose the nearest plausible horizontal furniture surface instead;
## this keeps keepsakes on desks/tables and out of bodies, floors, and walls.
func _nearest_art_surface(floor_data: Dictionary, room: Dictionary,
		wanted: Vector2) -> Dictionary:
	var rr: Array = room.rect
	var best := {"x": wanted.x, "y": wanted.y, "height": 0.82}
	var best_distance := INF
	for fu in floor_data.get("furniture", []):
		if not fu.has("rect"):
			continue
		var r: Array = fu.rect
		var cx := (float(r[0]) + float(r[2])) * 0.5
		var cy := (float(r[1]) + float(r[3])) * 0.5
		if cx < float(rr[0]) or cx > float(rr[2]) \
				or cy < float(rr[1]) or cy > float(rr[3]):
			continue
		var top := float(fu.get("z0", 0.0)) + float(fu.get("h", 0.0))
		var width := absf(float(r[2]) - float(r[0]))
		var depth := absf(float(r[3]) - float(r[1]))
		if top < 0.58 or top > 1.08 or width < 0.38 or depth < 0.30:
			continue
		var distance := wanted.distance_to(Vector2(cx, cy))
		if distance < best_distance:
			best_distance = distance
			best = {"x": cx, "y": cy, "height": top + 0.025}
	return best


## Finds a spot on a room wall where a picture can actually hang: a real
## wall segment behind it, no door or window cut through it at frame
## height, no furniture pressed against it. Tries the authored position
## first — the character chose that wall — then slides along the same wall,
## then concedes other walls. Returns {ok, x, y, yaw, wall}.
## Delegates to WallArtLaw — one law for every picture hook, shared with
## FoundArtPass and the story-decal placements. (The in-file original
## read openings from a key named "cuts" that the generator never wrote,
## so its doorway check never fired; the law reads the real key and also
## keeps art off the wainscot rail.)
func _legal_art_spot(floor_data: Dictionary, room: Dictionary,
		want_wall: String, want_along: float, height: float) -> Dictionary:
	return WallArtLaw.legal_spot(floor_data, room, want_wall, want_along,
			height)


func teleport_player(fid: String) -> void:
	var z: float = layout["meta"]["levels"][fid]
	if fid == "ROOF":
		player.global_position = GameBoot.b2g([0.0, -8.0, z + 0.1])
	else:
		player.global_position = GameBoot.b2g([4.3, 0.0, z + 0.1])
	player.velocity = Vector3.ZERO


func _physics_process(_delta: float) -> void:
	_update_floor_visibility()


## Coarse streaming: only the player's level and its vertical neighbors
## render — EXCEPT in the atrium, where the open eye is a sightline
## through every storey (lobby runner to skylight), so the whole stack
## renders there. The zone spans the stair volume plus the elevator
## hall, whose archway frames the same view. F01 stays always-on for
## glimpses down through the court windows.
## A free camera is the eye when one is flying; the player's parked body
## is not. Without this the debug camera renders whatever floor the body
## happens to stand on, and forcing the whole stack on instead costs a
## frame that never finishes.
var view_override: Node3D


func _update_floor_visibility() -> void:
	if view_override != null and is_instance_valid(view_override):
		_apply_visibility(view_override.global_position)
		return
	if player == null:
		return
	_apply_visibility(player.global_position)


func _apply_visibility(p: Vector3) -> void:
	var in_eye := absf(p.x) < 3.7 and p.z > -3.7 and p.z < 6.9
	# Outside the shell you are looking AT the building, and a
	# building that renders two storeys is a stage flat. The
	# envelope is 28 by 20 metres; a metre of margin keeps the
	# doorway from flickering the stack on and off.
	var outside := absf(p.x) > 15.2 or absf(p.z) > 11.2
	for fid in floor_nodes:
		var z: float = layout["meta"]["levels"][fid]
		floor_nodes[fid].visible = show_all_floors or in_eye or outside \
				or fid == "F01" \
				or absf(p.y - z) < 4.9 or (fid == "ROOF" and p.y > 15.0)

class_name ArcadeMachine
extends SubViewport
## One cabinet's board, running one cabinet's ROM.
##
## Everything above the `swc_*` files in this directory is a compiled World
## Package: a semantic scene of pure gameplay, plus a skin generated offline from
## a natural-language prompt. This node owns a SubViewport, builds that world
## inside it, and renders it at cabinet resolution. The prop hangs the texture on
## a screen; the panel makes it playable.
##
## The ROM is the same on every board. THE FRANCHISE, APEX RUN, SOMETHING IN THE
## HALL and nine others are all `arcade_pit`, byte-identical down to the
## colliders — `worldc invariance` fails the build if that ever stops being true.
## Only the skin differs, and the marquee, and the promises in attract mode.
##
## Three states:
##   ATTRACT  nobody is playing. The camera sweeps, the copy cycles, the game
##            claims to be a rhythm title over footage of a corridor shooting.
##   PLAYING  a panel has focus and is driving the player.
##   OVER     dead or finished; a few seconds of result, then back to attract.

signal state_changed(state: int)
signal score_changed(score: int)

enum State { COLD, ATTRACT, PLAYING, OVER }

## Cabinet screens are small and far away. Rendering higher costs twelve times
## over and buys nothing a bezel does not hide.
const RES := Vector2i(480, 360)

const _ATTRACT_SWEEP := 0.42   # radians either side of the spawn facing
const _ATTRACT_PERIOD := 11.0
const _OVER_SECONDS := 4.5

var cabinet: Dictionary = {}
var scene: SwcScene = null
var package: SwcPackage = null
var player: SwcPlayer = null
var state: State = State.COLD

## 0 = the compiled skin, 1 = the authored graybox. The middle is the point: it
## is where a cabinet stops being able to keep up the pretence, and it is applied
## per entity in a fixed order so the collapse reads as decay, not as flicker.
var degrade: float = 0.0:
	set(value):
		degrade = clampf(value, 0.0, 1.0)
		if is_inside_tree() and _built:
			SwcViewModes.apply_degrade(get_tree(), degrade, false)
			_blend_environment()
			_blend_held_object()

var _world: Node3D = null
var _entities: Dictionary = {}
var _spawners: Array = []
var _pickups: Array = []
var _breakables: Array = []
var _triggers: Array = []
var _objective: SwcObjective = null
var _enemy_container: Node3D = null
var _spawn := Transform3D()
var _spawn_params: Dictionary = {}
var _built := false
var _wave := 1
var _live_enemies := 0
var _score := 0
var _t := 0.0
var _over_t := 0.0
var _base_yaw := 0.0
var _overlay: ArcadeAttract = null
var _phosphor: SubViewport = null
var _environment: WorldEnvironment = null
var _dressed_environment: Environment = null
var _lights: Array[OmniLight3D] = []
var _held_stripped := false


func _init() -> void:
	size = RES
	# Its own World3D or the cabinet's corridor would share physics space with
	# the building the cabinet is standing in, and the outer player would be able
	# to walk into a wall that only exists on a screen.
	own_world_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	physics_object_picking = false
	audio_listener_enable_3d = false


## Build this cabinet's world. Deferred until the machine is first wanted: a row
## of twelve is twelve 3D worlds, and an arcade nobody has walked into yet should
## cost nothing.
func boot(entry: Dictionary, catalog_dir: String) -> bool:
	if _built:
		return true
	cabinet = entry

	var scene_path := catalog_dir.path_join(String(entry.get("scene", "semantic_scene.json")))
	scene = SwcScene.load_from(scene_path)
	if scene == null:
		push_error("ArcadeMachine: no semantic scene at %s" % scene_path)
		return false

	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)

	_enemy_container = Node3D.new()
	_enemy_container.name = "Enemies"
	add_child(_enemy_container)

	_environment = WorldEnvironment.new()
	_environment.name = "WorldEnvironment"
	add_child(_environment)

	var built := SwcWorldBuilder.build(scene, _world)
	_entities = built["entities"]
	_spawners = built["spawners"]
	_pickups = built["pickups"]
	_breakables = built["breakables"]
	_triggers = built["triggers"]
	_objective = built["objective"]
	_spawn = built["player_spawn"]
	_spawn_params = built["player_spawn_params"]

	player = SwcPlayer.create(scene.metrics, _spawn_params)
	add_child(player)
	player.teleport_to(_spawn)
	_base_yaw = player.rotation.y

	_wire()
	_built = true

	# The skin. A cabinet with no package still plays - that is the whole
	# architecture - it just plays in graybox, which is what a broken one does.
	var package_rel := String(entry.get("package", ""))
	if not package_rel.is_empty():
		package = SwcPackage.load_and_bind(catalog_dir.path_join(package_rel), _entities, scene)
		if package != null:
			package.apply_environment(_environment)
			_dressed_environment = _environment.environment
	if package == null:
		push_warning("ArcadeMachine: %s has no package; running graybox" % _title())
	_lights = []
	for entity_id in _entities:
		var entity: SwcEntity = _entities[entity_id]
		for node in entity.find_children("Light", "OmniLight3D", true, false):
			var light := node as OmniLight3D
			light.set_meta("dressed_color", light.light_color)
			_lights.append(light)
	# The object in the player's hands is presentation like everything else, so it
	# arrives with the package and leaves with it.
	if package != null and not package.held_object.is_empty():
		player.wear_held_object(package.held_object)
	if player.weapon != null:
		player.weapon.fired.connect(_on_weapon_fired)

	SwcViewModes.apply_degrade(get_tree(), degrade, false)
	_blend_environment()

	_overlay = ArcadeAttract.new()
	add_child(_overlay)
	_overlay.configure(cabinet)
	_build_phosphor()

	_enter(State.ATTRACT)
	return true


func _wire() -> void:
	for spawner_variant in _spawners:
		var spawner: SwcEnemySpawner = spawner_variant
		spawner.begin(player, _enemy_container, scene.metrics)
		spawner.enable_wave(_wave)
		spawner.spawned.connect(_on_enemy_spawned)
	for pickup_variant in _pickups:
		(pickup_variant as SwcPickup).collected.connect(_on_pickup)
	for trigger_variant in _triggers:
		(trigger_variant as SwcTriggerVolume).fired.connect(_on_trigger)
	if _objective != null:
		_objective.completed.connect(_on_objective)
	player.died.connect(_on_player_died)


# ------------------------------------------------------------------- lifecycle


## The last thing to go.
##
## The object in the player's hands is presentation like the walls, so it cannot
## survive into the graybox - two cabinets stripped to the authored level have to
## be showing the *same frame*, and a clipboard in one and a microphone in the
## other is the one difference that would still be visible. It goes late rather
## than early because it is the thing the player is holding, and losing it first
## would read as the game breaking rather than the dressing coming off.
const _HELD_SURVIVES_UNTIL := 0.85


func _blend_held_object() -> void:
	if player == null or package == null or package.held_object.is_empty():
		return
	var stripped := degrade >= _HELD_SURVIVES_UNTIL
	if stripped == _held_stripped:
		return
	_held_stripped = stripped
	player.wear_held_object({} if stripped else package.held_object)


## The light the world is seen under, dragged back toward neutral as the skin
## comes off.
##
## Stripping the meshes is not the whole reveal. Six cabinets that looked like six
## different games would still land on six differently-lit rooms, and "same
## layout, different game" is a much weaker read than "same room". The compiled
## environment is a generated asset like any other, so it degrades with the rest
## of them, and at full graybox every cabinet on the row is showing an identical
## picture. That is the moment the arcade is built around.
func _blend_environment() -> void:
	if _environment == null:
		return
	var neutral := _graybox_environment()
	if _dressed_environment == null or degrade >= 1.0:
		_environment.environment = neutral
	elif degrade <= 0.0:
		_environment.environment = _dressed_environment
	else:
		var blended := Environment.new()
		blended.background_mode = Environment.BG_COLOR
		blended.background_color = _dressed_environment.background_color.lerp(
			neutral.background_color, degrade
		)
		blended.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		blended.ambient_light_color = _dressed_environment.ambient_light_color.lerp(
			neutral.ambient_light_color, degrade
		)
		blended.ambient_light_energy = lerpf(
			_dressed_environment.ambient_light_energy, neutral.ambient_light_energy, degrade
		)
		# Fog is presentation to its last decimal, so it thins out with everything
		# else rather than surviving into the graybox.
		blended.fog_enabled = _dressed_environment.fog_enabled and degrade < 0.9
		if blended.fog_enabled:
			blended.fog_light_color = _dressed_environment.fog_light_color
			blended.fog_density = _dressed_environment.fog_density * (1.0 - degrade)
		blended.tonemap_mode = _dressed_environment.tonemap_mode
		blended.tonemap_white = _dressed_environment.tonemap_white
		blended.glow_enabled = _dressed_environment.glow_enabled and degrade < 0.75
		blended.glow_intensity = _dressed_environment.glow_intensity
		blended.glow_bloom = _dressed_environment.glow_bloom
		_environment.environment = blended

	# The fixtures too. Energy and range are gameplay - they decide what the
	# player can see - so only the tint moves.
	for light in _lights:
		if not is_instance_valid(light):
			continue
		var dressed: Color = light.get_meta("dressed_color", Color(1.0, 0.98, 0.94))
		light.light_color = dressed.lerp(Color(1.0, 0.98, 0.94), degrade)


func _graybox_environment() -> Environment:
	## Neutral, evenly lit, no fog. The graybox has to be *readable*, not moody -
	## and identical on every cabinet, or the reveal is not a reveal.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.09, 0.10, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.64, 0.70)
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	return environment


## The tube face: this board's picture with a phosphor's memory of it.
##
## A long-persistence scope keeps showing a bright trace for a second after the
## thing that made it has gone (ORISON_BIBLE VIII.5.g). That cannot be done in a
## fragment shader, which sees one frame and has no memory of the last - so it is
## accumulated here instead, in a 2D viewport that **never clears**:
##
##   each frame  a low-alpha black rect dims whatever is already on the glass
##               then the new frame is blended over it
##
## which is an exponential decay, which is what a phosphor is. Cheap: one 2D
## viewport per machine, drawing two full-screen rects.
func _build_phosphor() -> void:
	_phosphor = SubViewport.new()
	_phosphor.name = "Phosphor"
	_phosphor.size = RES
	_phosphor.transparent_bg = false
	_phosphor.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_phosphor.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_phosphor)

	# Drawn first: the decay. Raise its alpha for a shorter trail.
	var decay := ColorRect.new()
	decay.name = "Decay"
	decay.color = Color(0.0, 0.0, 0.0, 0.22)
	decay.size = RES
	_phosphor.add_child(decay)

	# Drawn second: this frame, partially, so it accumulates rather than replaces.
	var live := TextureRect.new()
	live.name = "Live"
	live.texture = get_texture()
	live.size = RES
	live.modulate = Color(1.0, 1.0, 1.0, 0.78)
	_phosphor.add_child(live)


## What the tube is showing, trail and all. This is what the prop hangs on the
## glass; `get_texture()` is the raw board behind it.
func scope_texture() -> ViewportTexture:
	return _phosphor.get_texture() if _phosphor != null else get_texture()


## Whether this machine has built its world yet.
func is_booted() -> bool:
	return _built


## Whether the board is powered. A cabinet across the room renders nothing.
func set_live(live: bool) -> void:
	render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	)
	if _phosphor != null:
		_phosphor.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
		)
	if _built:
		player.set_physics_process(live)
		player.set_process(live)


## A coin went in. The panel calls this when it takes focus.
func begin_play() -> void:
	if not _built:
		return
	_restart()
	_enter(State.PLAYING)


## The player walked away, or the panel closed. Back to attract, mid-game or not.
func end_play() -> void:
	if not _built:
		return
	player.release_controls()
	_enter(State.ATTRACT)


func _restart() -> void:
	_wave = 1
	_live_enemies = 0
	_score = 0
	score_changed.emit(_score)
	for child in _enemy_container.get_children():
		child.queue_free()
	for spawner_variant in _spawners:
		var spawner: SwcEnemySpawner = spawner_variant
		spawner.reset()
		spawner.enable_wave(_wave)
	for pickup_variant in _pickups:
		(pickup_variant as SwcPickup).respawn()
	for breakable_variant in _breakables:
		(breakable_variant as SwcBreakable).reset()
	for trigger_variant in _triggers:
		(trigger_variant as SwcTriggerVolume).reset()
	# Restoring what pickups and breakables hid, at whatever degrade the cabinet
	# is currently sitting at rather than snapping back to a full skin.
	SwcViewModes.apply_degrade(get_tree(), degrade, false)
	player.revive()
	player.teleport_to(_spawn)
	player.release_controls()


func _enter(next: State) -> void:
	state = next
	_t = 0.0
	if next == State.ATTRACT:
		_restart()
		player.set_look_enabled(false)
	elif next == State.PLAYING:
		player.set_look_enabled(true)
	elif next == State.OVER:
		_over_t = 0.0
		player.release_controls()
		player.set_look_enabled(false)
	if _overlay != null:
		_overlay.set_state(next, _score)
	state_changed.emit(next)


func _process(delta: float) -> void:
	if not _built:
		return
	_t += delta
	if state == State.ATTRACT:
		# A slow sweep across the pit. Enough motion that the screen reads as a
		# game running and not a photograph, without pretending to be a demo.
		player.rotation.y = _base_yaw + sin(_t * TAU / _ATTRACT_PERIOD) * _ATTRACT_SWEEP
	elif state == State.OVER:
		_over_t += delta
		if _over_t >= _OVER_SECONDS:
			_enter(State.ATTRACT)
	if _overlay != null:
		_overlay.tick(delta)


# ------------------------------------------------------------------- gameplay


func drive(move: Vector2, look: Vector2, fire: bool, jump: bool, sprint: bool) -> void:
	if _built and state == State.PLAYING:
		player.drive(move, look, fire, jump, sprint)


func try_interact() -> void:
	if not _built or state != State.PLAYING:
		return
	var target := player.hovered_interactable()
	if target != null:
		target.call("interact", player)


## A projectile chasing a shot that has already been resolved.
##
## `try_fire` did the raycast and the damage the instant the trigger went down;
## this is something to look at on the way to a hit that already happened. It is
## why a slow tumbling memo and a fast tracer are exactly as lethal.
##
## It stops being drawn as the cabinet degrades - at full graybox the world is
## back to what was authored, and a themed projectile is not part of that.
func _on_weapon_fired(from: Vector3, to: Vector3, _hit: bool) -> void:
	if degrade >= _HELD_SURVIVES_UNTIL or player.held_object.is_empty():
		return
	SwcHeldObject.launch(_world, player.held_object, from, to)


func _on_enemy_spawned(enemy: SwcEnemy) -> void:
	_live_enemies += 1
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(_enemy: SwcEnemy) -> void:
	_live_enemies = maxi(0, _live_enemies - 1)
	_score += 100
	score_changed.emit(_score)
	if _live_enemies == 0:
		_wave += 1
		for spawner_variant in _spawners:
			(spawner_variant as SwcEnemySpawner).enable_wave(_wave)


func _on_pickup(_kind: String, _amount: int) -> void:
	_score += 25
	score_changed.emit(_score)


func _on_trigger(_trigger_id: String, action: String) -> void:
	if action.begins_with("activate_wave_"):
		_wave = maxi(_wave, int(action.get_slice("_", 2)))
		for spawner_variant in _spawners:
			(spawner_variant as SwcEnemySpawner).enable_wave(_wave)


func _on_objective(_objective_id: String) -> void:
	_score += 1000
	score_changed.emit(_score)
	if _overlay != null:
		_overlay.set_result("CLEARED")
	_enter(State.OVER)


func _on_player_died() -> void:
	if _overlay != null:
		_overlay.set_result("GAME OVER")
	_enter(State.OVER)


# ----------------------------------------------------------------- description


func _title() -> String:
	return String(cabinet.get("title", cabinet.get("cabinet_id", "?")))


## What the cabinet claims, for the marquee and the bezel. Never what it runs.
func claimed_genre() -> String:
	return String(cabinet.get("claimed_genre", ""))


func score() -> int:
	return _score

extends Node
## WALK THE DREAM AND INTERROGATE IT.
##
##     godot --path game res://tests/DreamWalk.tscn
##
## Built because the owner said, correctly, that the way to find a rendering
## fault is to go and look at it: "let me walk around and try to identify these
## fucking rectangular prisms of light that are ruining the effect, i think one
## of the classes of object that get shaders got fucked."
##
## Every automated shot in this repo photographs three fixed viewpoints. That
## is the right instrument for a regression and the wrong one for a hunt,
## because it cannot be pointed at the thing that is actually wrong.
##
## CONTROLS
##   WASD / mouse   walk and look (the real PlayerController, real collision)
##   L              lamp
##   F              IDENTIFY whatever is under the crosshair -- node name,
##                  class, material type, shader, and which motif it is drawing
##   1..6           isolate one surface class; everything else is hidden
##   0              show everything again
##   TAB            hide every non-architecture object (props, particles,
##                  hazard visuals, the Tenant) in one keystroke
##   ESC            quit
##
## The isolate keys are the point. If a rectangular prism of light survives
## with walls, floor, ceiling, doors and shafts all hidden, then it is not
## architecture at all and the search is over in five seconds.

const SEED_HEX := "f123456789abcdef"

const CLASSES := [
	{"key": KEY_1, "name": "WALLS (spiral)", "motif": 1},
	{"key": KEY_2, "name": "FLOOR (mosaic)", "motif": 2},
	{"key": KEY_3, "name": "CEILING (canopy)", "motif": 0},
	{"key": KEY_4, "name": "DOORS (chevron)", "motif": 3},
	{"key": KEY_5, "name": "SHAFTS (eyes)", "motif": 4},
	{"key": KEY_6, "name": "NON-SHADER (props, particles, hazards)",
			"motif": -1},
]

var _root: DreamMazeRoot
var _label: Label
var _isolated := -99


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	_root = scene.instantiate() as DreamMazeRoot
	_root.configure_dream({
		"case_id": "mina_caption_crisis",
		"profile_id": "mina_release_print", "window": {},
		"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
	})
	add_child(_root)
	await get_tree().process_frame
	# Not autonomous: the 28 s run cap would end the walk mid-inspection.
	_root.autonomous = false
	_build_hud()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_census()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(18, 14)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color("d9c996"))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	_set_text("F identify   1-6 isolate class   0 all   TAB architecture only"
			+ "   L lamp   ESC quit")


func _set_text(s: String) -> void:
	if _label:
		_label.text = s


## What the maze is actually made of, printed once at startup. If a class is
## missing here it never reached the geometry at all.
func _census() -> void:
	var counts := {}
	for node in _root.find_children("*", "GeometryInstance3D", true, false):
		counts[_class_of(node)] = int(counts.get(_class_of(node), 0)) + 1
	print("[DREAM WALK] surface census: %s" % str(counts))


## Which class a piece of geometry belongs to, taken from the MATERIAL rather
## than from the node name -- a name can lie about what is being drawn and the
## motif uniform cannot.
func _class_of(node: Node) -> String:
	var geometry := node as GeometryInstance3D
	if geometry == null:
		return "not-geometry"
	var material := geometry.material_override as ShaderMaterial
	if material == null:
		var over: Material = geometry.material_override
		return "NO-SHADER (%s)" % (over.get_class() if over else "none")
	var motif: Variant = material.get_shader_parameter("motif")
	for entry in CLASSES:
		if int(entry.motif) == int(motif):
			return str(entry.name)
	return "shader motif=%s" % str(motif)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().quit(0)
			KEY_F:
				_identify()
			KEY_0:
				_isolate(-99)
			KEY_TAB:
				_architecture_only()
			_:
				for entry in CLASSES:
					if event.keycode == int(entry.key):
						_isolate(int(entry.motif))


## THE ONE THAT MATTERS. Ray from the eye, and whatever it lands on is named
## in full: node, class, the material actually bound to it, and the motif it
## claims to be drawing. Point at the offending prism and press F.
func _identify() -> void:
	var camera: Camera3D = _root.player.camera
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 40.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_root.player.get_rid()]
	var hit := get_viewport().get_world_3d().direct_space_state \
			.intersect_ray(query)
	if hit.is_empty():
		_set_text("F: nothing under the crosshair within 40 m")
		print("[DREAM WALK] identify: nothing hit")
		return
	# The collider is a body; the thing being DRAWN is usually a sibling or a
	# child of it, so report the nearest geometry rather than the body.
	var node: Node = hit.collider
	var geometry := _nearest_geometry(node)
	var lines := "F: %s\n  collider %s\n  drawn by %s\n  class %s" % [
			str(hit.position).pad_decimals(2), node.name,
			geometry.name if geometry else "(no GeometryInstance3D found)",
			_class_of(geometry) if geometry else "?"]
	if geometry:
		var material := geometry.material_override
		lines += "\n  material %s" % (material.get_class() if material
				else "none (inherits mesh material)")
		if material is ShaderMaterial:
			var shader: Shader = (material as ShaderMaterial).shader
			lines += "\n  shader %s" % (shader.resource_path if shader
					else "NULL")
			lines += "\n  compiled %s" % (not shader.get_shader_uniform_list()
					.is_empty() if shader else false)
	_set_text(lines)
	print("[DREAM WALK] identify:\n%s" % lines)


func _nearest_geometry(node: Node) -> GeometryInstance3D:
	if node is GeometryInstance3D:
		return node
	for child in node.get_children():
		if child is GeometryInstance3D:
			return child
	var parent := node.get_parent()
	if parent:
		for sibling in parent.get_children():
			if sibling is GeometryInstance3D:
				return sibling
	return null


## Hide everything that is not the named class. Five keystrokes bracket the
## fault: whatever is still glowing when all five architecture classes are off
## is not architecture.
func _isolate(motif: int) -> void:
	_isolated = motif
	var shown := 0
	var hidden := 0
	for node in _root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry == null:
			continue
		var want := motif == -99
		if not want:
			var material := geometry.material_override as ShaderMaterial
			if motif == -1:
				want = material == null
			elif material != null:
				want = int(material.get_shader_parameter("motif")) == motif
		geometry.visible = want
		if want:
			shown += 1
		else:
			hidden += 1
	var name := "EVERYTHING"
	for entry in CLASSES:
		if int(entry.motif) == motif:
			name = str(entry.name)
	_set_text("ISOLATED: %s\n  %d shown, %d hidden\n  (0 = all back)"
			% [name, shown, hidden])
	print("[DREAM WALK] isolate %s: %d shown, %d hidden"
			% [name, shown, hidden])


## Everything that is not maze architecture, off in one keystroke: the motes,
## the jewel rain, the hazard conduit and its arc, the Tenant's borrowed mesh.
## If the prisms survive this AND the five class isolations, they are coming
## from a light rather than from geometry.
func _architecture_only() -> void:
	var hidden := 0
	for node in _root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry == null:
			continue
		if geometry.material_override is ShaderMaterial:
			continue
		geometry.visible = false
		hidden += 1
	for node in _root.find_children("*", "CPUParticles3D", true, false):
		node.visible = false
		hidden += 1
	_set_text("ARCHITECTURE ONLY: %d non-shader objects hidden\n"
			% hidden + "  (props, particles, hazard visuals, the Tenant)")
	print("[DREAM WALK] architecture only: %d hidden" % hidden)

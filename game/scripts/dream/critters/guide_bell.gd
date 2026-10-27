extends Node3D
## A presentation-owned sessile cell. Neither this cell nor its symbionts
## participate in the ecology controller or tardigrade prey census.
enum State { UNSPAWNED, GERMINATING, INDICATING, PASSED_PENDING, WILTING, RETRACTING, CLEARED }
const PASS_MARGIN := .55
const PASS_CONFIRM_S := .4
var state := State.UNSPAWNED
var elapsed := 0.0
var age := 0.0
var remaining_to_target_m := 0.0
var route_coordinate := Vector3.ZERO
var direction_target := Vector3.ZERO
var surface: WeakRef
var surface_transform := Transform3D.IDENTITY
var materials: Array[ShaderMaterial] = []
var optical_field: RefCounted
var history: Array[Dictionary] = []
var symbionts: Array[Node3D] = []
var geometry: Node3D
var seed_value := 0
var reason := ""
var maturation := 0.0
var colony_alarm := 0.0
var route_revision := 0
var _surface_name := ""
var _display_direction := Vector3.RIGHT

func start(anchor: Dictionary,remaining: float,direction: Vector3,seed_id: int,maturity: float,field: RefCounted=null) -> bool:
	if state!=State.UNSPAWNED or not is_instance_valid(anchor.get("owner")): return false
	surface=weakref(anchor.owner); surface_transform=anchor.owner.global_transform
	_surface_name=str(anchor.owner.get_path())
	global_position=anchor.position
	route_coordinate=anchor.coordinate; remaining_to_target_m=remaining; direction_target=direction
	seed_value=seed_id; maturation=maturity; optical_field=field
	_display_direction=(direction-global_position).normalized()
	var packed := load("res://assets/dream/guide_bell/guide_bell.glb") as PackedScene
	if packed==null: clear_immediately("asset_unavailable"); return false
	geometry=packed.instantiate(); add_child(geometry)
	var shared: Dictionary={}
	# The base never rotates. Direction bends only the distal stalk and bell.
	for draw: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		var role := str(draw.name)
		if role.begins_with("Cilium_2_") and maturity<=.5:
			draw.free(); continue
		var stock := "membrane" if role.begins_with("Membrane") or role.begins_with("Vacuole") else "tissue"
		var key := stock+str(role.begins_with("Cilium"))+str(role.begins_with("Vacuole") or role.begins_with("Nucleus"))+str(role.begins_with("Granule"))
		if shared.has(key):
			draw.material_override=shared[key]; draw.layers=1<<17
			draw.set_meta(&"lamp_optical_receiver",true)
			if stock=="membrane": draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if role.begins_with("Cilium_2_"): draw.visible=maturity>.5
			continue
		var mat := ShaderMaterial.new()
		mat.shader=load("res://shaders/guide_bell_membrane.gdshader" if stock=="membrane" else "res://shaders/guide_bell_tissue.gdshader")
		for channel in ["albedo","normal","roughness"]: mat.set_shader_parameter(channel+"_map",load("res://assets/dream/guide_bell/"+stock+"_"+channel+".png"))
		mat.set_shader_parameter("seed_phase",float(posmod(seed_id,997))*.01)
		mat.set_shader_parameter("cilia",1.0 if role.begins_with("Cilium") else 0.0)
		mat.set_shader_parameter("organ",1.0 if role.begins_with("Vacuole") or role.begins_with("Nucleus") else 0.0)
		mat.set_shader_parameter("maturity",maturity)
		mat.set_shader_parameter("particulate",1.0 if role.begins_with("Granule") else 0.0)
		draw.material_override=mat; draw.layers=1<<17
		draw.set_meta(&"lamp_optical_receiver",true)
		if stock=="membrane": draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		materials.append(mat)
		shared[key]=mat
		if optical_field!=null: optical_field.bind_material(mat)
	var prey := load("res://assets/dream/critters_blender/euplotes/euplotes.glb") as PackedScene
	if prey!=null:
		var prey_material := ShaderMaterial.new()
		prey_material.shader=load("res://shaders/guide_bell_tissue.gdshader")
		prey_material.set_shader_parameter("symbiont",true)
		for channel in ["albedo","normal","roughness"]: prey_material.set_shader_parameter(channel+"_map",load("res://assets/dream/guide_bell/tissue_"+channel+".png"))
		materials.append(prey_material)
		if optical_field!=null: optical_field.bind_material(prey_material)
		for i in mini(3,int(maturity*4)):
			var local := prey.instantiate() as Node3D
			local.name="PresentationEuplotes%d"%i
			local.scale=Vector3.ONE*.055
			add_child(local); symbionts.append(local)
			for draw: MeshInstance3D in local.find_children("*","MeshInstance3D",true,false):
				draw.material_override=prey_material; draw.layers=1<<17
	_enter(State.GERMINATING,"route_activated")
	return true

func _enter(next: State,why: String) -> void:
	state=next; elapsed=0; reason=why
	history.append({"state":State.keys()[state],"age":age,"reason":why})

func update_progress(valid: bool,player_remaining: float,_delta: float,in_work_zone:=false) -> void:
	if state==State.CLEARED: return
	if not valid: clear_immediately("invalid_route"); return
	var passed := player_remaining<remaining_to_target_m-PASS_MARGIN or in_work_zone
	if state==State.INDICATING and passed: _enter(State.PASSED_PENDING,"player_passed")
	elif state==State.PASSED_PENDING:
		if not passed: _enter(State.INDICATING,"progress_jitter")
		elif elapsed>=PASS_CONFIRM_S: _enter(State.WILTING,"pass_confirmed")

func retire(why: String) -> void:
	if state<State.WILTING: _enter(State.WILTING,why)

func _process(delta: float) -> void:
	if state==State.CLEARED or state==State.UNSPAWNED: return
	var owner: Node3D=surface.get_ref() if surface!=null else null
	if not is_instance_valid(owner) or not owner.is_inside_tree() or not owner.is_visible_in_tree() or owner.is_queued_for_deletion() or owner.global_transform!=surface_transform:
		clear_immediately("surface_unloaded_or_moved"); return
	age+=delta; elapsed+=delta
	if state==State.GERMINATING and elapsed>=1.3: _enter(State.INDICATING,"grown")
	elif state==State.WILTING and elapsed>=1.6: _enter(State.RETRACTING,"pressure_lost")
	elif state==State.RETRACTING and elapsed>=.85: clear_immediately("retracted"); return
	var wilt := clampf(elapsed/1.6,0,1) if state==State.WILTING else (1.0 if state>=State.RETRACTING else 0.0)
	var retract := clampf(elapsed/.85,0,1) if state==State.RETRACTING else 0.0
	var wanted := (direction_target-global_position).normalized()
	_display_direction=_display_direction.lerp(wanted,1.0-exp(-delta*1.8)).normalized()
	var direction := global_basis.inverse()*_display_direction
	for mat in materials:
		mat.set_shader_parameter("organ_time",age)
		mat.set_shader_parameter("growth",clampf(elapsed/1.3,0,1) if state==State.GERMINATING else 1.0)
		mat.set_shader_parameter("wilt",wilt); mat.set_shader_parameter("retract",retract)
		mat.set_shader_parameter("route_direction",direction)
		mat.set_shader_parameter("colony_alarm",colony_alarm)
	for i in symbionts.size():
		var phase := age*1.3+i*2.1
		var retreat := maxf(wilt,colony_alarm)
		var radius := .08*(1.0-smoothstep(.15,.65,retreat))
		var direction_side := Vector3(direction.z,0,-direction.x)
		symbionts[i].position=direction*.045+direction_side*cos(phase)*radius+Vector3.UP*(.012-.08*wilt)
		symbionts[i].rotation.y=phase+.1*sin(age*17.0+i)
		symbionts[i].visible=retreat<.7

func clear_immediately(why: String) -> void:
	if state==State.CLEARED: return
	for mat in materials:
		if optical_field!=null: optical_field.unbind_material(mat)
	materials.clear(); optical_field=null
	for child in get_children(): child.free()
	symbionts.clear(); geometry=null; surface=null
	_enter(State.CLEARED,why)

func census() -> Dictionary:
	return {"remaining_to_target_m":remaining_to_target_m,"route_coordinate":[route_coordinate.x,route_coordinate.y,route_coordinate.z],
		"surface_owner":_surface_name,"route_revision":route_revision,
		"direction_target":[direction_target.x,direction_target.y,direction_target.z],"state":State.keys()[state],"transitions":history.duplicate(true),
		"optical_registrations":materials.size(),"symbiont_ownership":"breadcrumb_presentation",
		"symbionts":symbionts.size(),"reason":reason}

func _exit_tree() -> void: clear_immediately("scene_teardown")

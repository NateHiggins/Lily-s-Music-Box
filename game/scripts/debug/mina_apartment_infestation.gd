extends Node3D
## Debug staging on real V2 surfaces. Shared production organs own all behavior.
## No campaign writes, replacement room, colliders, or collectible creatures.
const Receiver := preload("res://scripts/reality/apartment_encroachment.gd")
const Roster := preload("res://scripts/debug/dream_ecology_warehouse.gd").FaunaRoster
class Focus:
	extends Node3D
	var player: Node3D
	func lamp_pose() -> Dictionary:
		return player.lamp_pose() if is_instance_valid(player) else {}
var receiver: ApartmentEncroachment
var field: DreamFieldController
var living: LivingField
var director: DreamEcologyDirector
var margin: DreamMarginController
var hero: DreamHeroTentacle
var residue: DreamResidue
var controllers: Array = []
var roster := Roster.new()
var contacts: Array[Dictionary] = []
var originals: Array[Dictionary] = []
var errors: Array[String] = []
var stand := Vector3.ZERO
var target := Vector3.ZERO
var ready_for_play := false
const CASE := "mina_caption_crisis"

func setup(world: Node3D) -> bool:
	if GameBoot.launch_mode != GameBoot.LaunchMode.DEBUG: return false
	var block: Node3D = world._blockout
	var rooms: Array[Node3D] = []
	var bounds := AABB()
	var first := true
	for space: Dictionary in world.layout.spaces:
		if not str(space.id).begins_with("F02_A_"): continue
		var room := block.get_node_or_null(str(space.id)) as Node3D
		if room == null: continue
		rooms.append(room)
		var r: Array = space.rect
		var y: float = block.level_y[space.level]
		for x in [r[0],r[2]]:
			for z in [r[1],r[3]]:
				var p: Vector3 = block.to_global(Vector3(float(x),y,float(z)))
				if first: bounds=AABB(p,Vector3.ZERO); first=false
				else: bounds=bounds.expand(p)
	if rooms.is_empty(): errors.append("Mina rooms missing"); return false
	rooms.sort_custom(func(a: Node,b: Node): return str(a.name)=="F02_A_MAIN" and str(b.name)!="F02_A_MAIN")
	var rect := Vector4(bounds.position.x,bounds.position.z,bounds.end.x,bounds.end.z)
	# Use real world collision for every specimen's supporting surface.
	var space_state := get_world_3d().direct_space_state
	for room in rooms:
		var floor_mesh := room.get_node_or_null("Floor") as Node3D
		if floor_mesh == null: continue
		var centre: Vector3 = floor_mesh.global_position + Vector3.UP*1.4
		for i in 12:
			var angle := TAU*float(i)/12.0
			var hit := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
				centre,centre+Vector3(cos(angle),0,sin(angle))*12.0,1))
			if hit.is_empty() or absf(hit.normal.y)>.1: continue
			if not bounds.grow(.3).expand(bounds.end+Vector3.UP*3).has_point(hit.position): continue
			contacts.append(hit)
	if contacts.size()<16: errors.append("Insufficient real room contacts"); return false
	target=contacts[0].position
	stand=target+contacts[0].normal*1.8
	stand.y=bounds.position.y+.05
	field=DreamFieldController.new(); add_child(field)
	field.setup(92601,rect,bounds.position.y,target)
	# Keep the infestation anchored here while the player visits the zoo.
	var anchor := Focus.new(); anchor.player=world.player; add_child(anchor); anchor.global_position=target
	field.player=anchor
	living=LivingField.new(); living.configure(rect,bounds.position.y,92602)
	field.living_field=living
	residue=DreamResidue.new(); add_child(residue); residue.setup(92603); residue.field=field
	director=DreamEcologyDirector.new(); add_child(director); director.setup(92604)
	director.field=field; director.critters=roster
	director._try_listen()
	margin=DreamMarginController.new(); add_child(margin); margin.setup(field,92605)
	margin.director=director; margin.critters=roster; director.margin=margin
	var palps := DreamPalpRenderer.new(); add_child(palps); palps.setup(margin)
	hero=DreamHeroTentacle.new(); add_child(hero)
	hero.setup(92606,target+contacts[0].normal*.04,contacts[0].normal)
	hero.field=field; hero.margin=margin; hero.critters=roster; hero.watch=world.player
	margin.hero=hero; director.hero=hero
	hero.touched.connect(func(at: Vector3,n: Vector3): residue.lay(at,n,.16,1.0,3.6))
	hero.lifecycle_shed.connect(residue.lay_memory)
	for group in 2:
		var controller := DreamCritterController.new(); add_child(controller)
		controller.setup(field,92610+group)
		if not controller.enable_blender_visuals(): errors.append(controller.blender_error)
		controller.debug_set_id_base(group*100000)
		controller.margin=margin; controller.residue=residue; controller.director=director
		controller.hero=hero; controller.ecology_director=director
		controllers.append(controller); roster.batches.append(controller)
	for kind in 16:
		var hit: Dictionary=contacts[kind*contacts.size()/16]
		controllers[kind/8].debug_spawn_specimen(kind,92700+kind,hit.position,hit.normal)
	for controller in controllers: controller._push()
	receiver=Receiver.new(); add_child(receiver); receiver.set_physics_process(false)
	receiver.ecology=director
	receiver.fields[str(name)]=living
	receiver.units[CASE]={"rect":rect,"floor_y":bounds.position.y,"floor_node":self}
	receiver.field_source[CASE]=living.add_source(target,0)
	receiver.ecology_source[CASE]=92600
	living.set_source_intensity(receiver.field_source[CASE],.9)
	# Distributed sources let all rooms grow, not just the hero's corner.
	for i in range(4,contacts.size(),4):
		living.set_source_intensity(living.add_source(contacts[i].position,0),.85)
	var colony = director.register_moss_colony(92600,92600,target)
	var moss := DreamMossColonyRenderer.new(); add_child(moss); moss.setup(colony)
	receiver.moss_presentations[92600]=moss
	receiver._read_substance_keys()
	var plates: Dictionary=receiver._plates_for("mina")
	var materials: Array=[]
	for room in rooms:
		for mesh: MeshInstance3D in room.find_children("*","MeshInstance3D",true,false):
			if not Receiver._living_candidate(mesh,room) or mesh.mesh==null: continue
			for surface in mesh.mesh.get_surface_count():
				var base := mesh.get_active_material(surface)
				var mat: ShaderMaterial
				if base is ShaderMaterial:
					mat=base.duplicate()
					mat.set_shader_parameter("has_encroachment",true)
					mat.set_shader_parameter("unit_rect",rect)
					mat.set_shader_parameter("floor_y",bounds.position.y)
					for key in plates: mat.set_shader_parameter("plate_"+key,plates[key])
				elif base is BaseMaterial3D: mat=receiver._material_for(base,plates,rect,bounds.position.y)
				else: continue
				mat.set_shader_parameter("intensity",.9)
				receiver._bind_living(mat,str(name))
				originals.append({"mesh":mesh,"surface":surface,"override":mesh.get_surface_override_material(surface),"whole":mesh.material_override})
				mesh.material_override=null
				mesh.set_surface_override_material(surface,mat); materials.append(mat)
	receiver.storey_materials[str(name)]=materials
	var tendrils := DreamSurfaceTendrils.new(); add_child(tendrils); tendrils.setup(field,92620)
	margin.arrange_archetype_row(target+contacts[0].normal*.05,contacts[0].normal,.24)
	margin.frozen=false
	for palp: Dictionary in margin.palps: palp.act_left=1.6
	ready_for_play=errors.is_empty()
	return ready_for_play

func _physics_process(delta: float) -> void:
	if not ready_for_play: return
	receiver._receive_architecture_signals()
	if living.tick(delta):
		receiver._tend_moss_colonies(str(name),living,delta)
		receiver._push_living_lifecycle(str(name),living)
		for material: ShaderMaterial in receiver.storey_materials[str(name)]:
			material.set_shader_parameter("living_pulse",living.pulse_phase())

func _exit_tree() -> void:
	for row: Dictionary in originals:
		if is_instance_valid(row.mesh):
			row.mesh.set_surface_override_material(row.surface,row.override)
			row.mesh.material_override=row.whole

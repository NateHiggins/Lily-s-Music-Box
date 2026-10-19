extends Node
## Observe the actual live controller; no fabricated or interpolated route poses.
## Observe actual post-controller physics poses; never interpolate witnesses.
var world: OrisonV2RuntimeRoot
var player: PlayerController
var samples: Array[Dictionary]=[]
var claims: Dictionary={}
var _floors: Array[Dictionary]=[]

func configure(current: OrisonV2RuntimeRoot) -> void:
	world=current;player=world.player
	process_physics_priority=100
	for identity: String in world._exterior_resolver.instance_ids():
		var instance: Dictionary=world._exterior_resolver.instance_record(identity)
		var template: Dictionary=world._exterior_resolver.template_record_for_instance(identity)
		var region: Dictionary=world._exterior_resolver.region_record(str(instance.region_id))
		for source: Dictionary in template.surfaces:
			if str(source.kind)!="walkable":continue
			var floor: Dictionary=world._exterior_resolver.resolve_surface(identity,str(source.id))
			floor["boundary"]=region.boundary.duplicate(true)
			_floors.append(floor)

func _disc_inside(boundary: Array,point: Vector2,radius: float) -> bool:
	var inside:=false;var closest:=INF
	for i in boundary.size():
		var first: Array=boundary[i];var second: Array=boundary[(i+1)%boundary.size()]
		var a:=Vector2(first[0],first[1]);var b:=Vector2(second[0],second[1])
		if (a.y>point.y)!=(b.y>point.y) and point.x<(b.x-a.x)*(point.y-a.y)/(b.y-a.y)+a.x:inside=not inside
		var edge:=b-a
		var t:=clampf((point-a).dot(edge)/edge.length_squared(),0,1)
		closest=minf(closest,point.distance_to(a+edge*t))
	return inside and closest>=radius+.005

func _physics_process(_delta: float) -> void:
	var at: Vector3=world.adapter.root.to_local(player.global_position)
	var row: Dictionary={"actual":[at.x,at.y,at.z],"physics_frame":Engine.get_physics_frames(),
		"noclip":player.noclip,"collision_mask":player.collision_mask,
		"capsule_radius":player._capsule.radius,"capsule_height":player._capsule.height,
		"on_floor":player.is_on_floor()}
	var index:=samples.size();samples.append(row)
	if player.noclip or not player.is_on_floor() or player.collision_mask!=1:return
	if claims.size()==6:return
	var source_point: Vector3=world.to_local(player.global_position)
	for floor: Dictionary in _floors:
		var region:=str(floor.region_id)
		if claims.has(region):continue
		var radius: float=player._capsule.radius
		if not _disc_inside(floor.boundary,Vector2(source_point.x,source_point.z),radius):continue
		var offset: Vector3=source_point-floor.point
		if (floor.normal as Vector3).y<.999 or absf(offset.y)>=.15:continue
		if absf(offset.dot(floor.u_axis))+radius+.005>float(floor.size_m[0])*.5 or absf(offset.dot(floor.v_axis))+radius+.005>float(floor.size_m[1])*.5:continue
		# Query live geometry only after an actual body pose fits the source
		# polygon and floor, rather than scanning two subtrees every frame.
		var owner: Node3D=world.exterior_cell.instance_node(str(floor.instance_id))
		var resident:=false
		if is_instance_valid(owner):resident=owner.is_inside_tree() and not owner.find_children("*","MeshInstance3D",true,false).is_empty()
		else:
			for state: Dictionary in world.public_regions.snapshot():
				if str(state.instance_id)==str(floor.instance_id):resident=bool(state.resident) and state.owner!=null
		if not resident:continue
		var ray:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*.15,player.global_position-Vector3.UP*.15,1,[player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector3).y<.7:continue
		claims[region]={"id":region,"instance_id":str(floor.instance_id),"floor_surface_id":str(floor.surface_id),
			"leg":"exterior_regions","sample_index":index,"actual":row.actual.duplicate(),
			"geometry_resident":true,"on_floor":true,"floor_collider_path":str((hit.collider as Node).get_path())}

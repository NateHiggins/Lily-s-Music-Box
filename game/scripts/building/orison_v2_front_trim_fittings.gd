extends RefCounted
## Bounded visual splices; wall bodies, actors and control/save owners remain.
const DATA_PATH="res://data/orison_v2/front_lighting_trim.json"
var errors: Array[String]=[]
var installed: Array[MeshInstance3D]=[]
var changed_batches: Array[Dictionary]=[]

static func _pose(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))

func mount(world: Node3D) -> bool:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if data.get("schema_version")!=1:return false
	for pair: Array in [[data.asset,data.asset_sha256],[data.profile_asset,data.profile_asset_sha256]]:
		if FileAccess.file_exists(str(pair[0])) and FileAccess.get_sha256(str(pair[0]))!=str(pair[1]):
			errors.append("trim source asset changed: "+str(pair[0]));return false
	var packed:=load(str(data.asset)) as PackedScene
	if packed==null:return false
	var model:=packed.instantiate()
	var variants: Dictionary={}
	if not is_equal_approx(float(data.tile),float(MatLib.SETS[str(data.catalog_key)][3])):
		model.free();errors.append("trim source tile no longer matches its registered stock");return false
	# These splices continue HistoricMillwork's painted coating. Their native
	# charts are in metres; select the coating's physical scale, not the old
	# trim texture's tile size retained in the geometry source record.
	var finish_key: String="door_paint" if str(data.catalog_key)=="trim" else str(data.catalog_key)
	var material:=MatLib.get_mat(finish_key).duplicate() as StandardMaterial3D
	material.uv1_triplanar=false;material.uv1_scale=Vector3.ONE/float(MatLib.SETS[finish_key][3])
	material.normal_scale=1.0 if finish_key=="door_paint" else .12
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for row: Dictionary in data.parts:
		var node:=model.find_child(str(row.name),true,false) as MeshInstance3D
		if node==null:model.free();errors.append("missing native trim stock "+str(row.name));return false
		var mesh:=node.mesh.duplicate() as ArrayMesh
		for surface in mesh.get_surface_count():mesh.surface_set_material(surface,material)
		if not variants.has(str(row.variant)):variants[str(row.variant)]=[]
		variants[str(row.variant)].append({"name":str(row.name),"mesh":mesh,"pose":node.transform})
	model.free()
	var proposed: Array[Dictionary]=[]
	for row: Dictionary in data.rooms:
		var room:=world.adapter.root.get_node_or_null(str(row.room)) as Node3D
		var batch:=room.get_node_or_null("HistoricMillwork") as MultiMeshInstance3D if room!=null else null
		if batch==null:errors.append("missing trim room "+str(row.room));return false
		var original:=batch.multimesh
		var sources: PackedStringArray=batch.get_meta("wall_sources")
		var cuts: Dictionary={}
		for cut: Dictionary in row.cuts:
			var index:=int(cut.index)
			if cuts.has(index) or index<0 or index>=original.instance_count or sources[index]!=str(cut.source):
				errors.append("trim source identity changed "+str(row.room));return false
			var actual: Transform3D=batch.transform*original.get_instance_transform(index)
			if not actual.is_equal_approx(_pose(cut.expected)):
				errors.append("trim source pose changed "+str(row.room)+" / "+str(index));return false
			cuts[index]=cut.intervals
		var poses: Array[Transform3D]=[]
		var owners:=PackedStringArray()
		var retained:=0
		for index in original.instance_count:
			var at:=original.get_instance_transform(index)
			if not cuts.has(index):poses.append(at);owners.append(sources[index]);retained+=1;continue
			var start: float=-.5
			for interval: Array in cuts[index]:
				var low:=float(interval[0]);var high:=float(interval[1])
				if low<start-.00001 or high<=low or high>.50001:
					errors.append("invalid trim splice interval");return false
				_append_run(poses,owners,at,start,low,sources[index]);start=high
			_append_run(poses,owners,at,start,.5,sources[index])
		var replacement:=MultiMesh.new();replacement.transform_format=MultiMesh.TRANSFORM_3D;replacement.use_custom_data=true
		replacement.mesh=original.mesh;replacement.instance_count=poses.size()
		for index in poses.size():
			var at: Transform3D=poses[index]
			replacement.set_instance_transform(index,at)
			replacement.set_instance_custom_data(index,Color(at.basis.x.length(),at.basis.y.length(),at.basis.z.length(),0))
		proposed.append({"batch":batch,"before":original,"before_sources":sources,"after":replacement,"sources":owners,"unchanged":retained})
	# Resolve every replacement before changing any original batch.
	var mounts: Array[Dictionary]=[]
	for row: Dictionary in data.fittings:
		var room:=world.adapter.root.get_node_or_null(str(row.room)) as Node3D
		if room==null or not variants.has(str(row.variant)):errors.append("missing trim fitting owner");return false
		mounts.append({"room":room,"owner":str(row.owner),"pose":_pose(row.pose),"parts":variants[str(row.variant)]})
	for row: Dictionary in proposed:
		row.batch.multimesh=row.after;row.batch.set_meta("wall_sources",row.sources)
		changed_batches.append({"batch":weakref(row.batch),"before":row.before,"before_sources":row.before_sources,"unchanged":row.unchanged})
	for row: Dictionary in mounts:
		for part: Dictionary in row.parts:
			var draw:=MeshInstance3D.new();draw.name=row.owner+"_"+part.name
			draw.mesh=part.mesh;row.room.add_child(draw)
			draw.transform=row.pose*part.pose
			draw.set_meta("native_front_trim_fit",row.owner);draw.set_meta("material_key",finish_key)
			installed.append(draw)
	return true

static func _append_run(poses: Array[Transform3D],sources: PackedStringArray,original: Transform3D,low: float,high: float,owner: String) -> void:
	if (high-low)*original.basis.x.length()<.00001:return
	var at:=original;at.origin=original*Vector3((low+high)/2,0,0);at.basis.x*=high-low
	poses.append(at);sources.append(owner)

func finish() -> void:
	installed.clear();changed_batches.clear()

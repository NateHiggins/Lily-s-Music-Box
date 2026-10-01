extends RefCounted
## Static attachments use the built shell's real bearing boxes. No new
## service, collision, motor, register, simulation or maintenance authority.

const MODEL := preload("res://assets/props/duct_hanger.glb")
const DUCT_HALF := .09
const MAX_SPAN := 1.2
var solids: Array[AABB] = []
var ceilings: Array[AABB] = []
var stations: Array[Transform3D] = []

func configure(root: Node3D, layout: Dictionary) -> void:
	# Resolve the actual room shells rather than recreate wall/aperture rules.
	for record: Dictionary in layout.spaces:
		var room := root.get_node_or_null(str(record.id)) as Node3D
		if room == null: continue
		for part in room.get_children():
			if not part is MeshInstance3D: continue
			var bounds: AABB = (root.global_transform.affine_inverse() * part.global_transform) * part.get_aabb()
			if str(part.name) in ["Floor", "Ceiling"]: ceilings.append(bounds)
			elif str(part.name).begins_with("Wall") and part.get_node_or_null("Collision") != null:
				solids.append(bounds)
	for record: Dictionary in layout.risers:
		if not bool(record.get("solid", true)): continue
		var owner := root.get_node_or_null(str(record.id)) as Node3D
		if owner == null: continue
		var parts: Array[Node] = [owner]
		parts.append_array(owner.find_children("*", "MeshInstance3D", true, false))
		for part in parts:
			if part is MeshInstance3D and part.get_node_or_null("Collision") != null:
				solids.append((root.global_transform.affine_inverse() * part.global_transform) * part.get_aabb())

func begin_stack() -> void:
	stations.clear()

func append_branch(a: Vector3, b: Vector3, ceiling_y: float) -> void:
	var delta := b - a
	if delta.length() < .15 or absf(delta.y) > .001: return
	var along_x := absf(delta.x) > absf(delta.z)
	var basis := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * .5)
	var count := maxi(1, int(ceil(delta.length() / MAX_SPAN)))
	for index in count:
		var at := a.lerp(b, (float(index) + .5) / float(count))
		var duct := AABB(at - Vector3.ONE * DUCT_HALF, Vector3.ONE * DUCT_HALF * 2)
		var concealed := false
		for solid in solids:
			if solid.grow(.0001).encloses(duct):
				concealed = true
				break
		if concealed: continue
		# Both plates must meet an existing slab/ceiling. A chase or court
		# gap cannot receive a floating rod just to satisfy a spacing census.
		var carried := true
		for side in [-1.0, 1.0]:
			var contact := at + basis * Vector3(0,0,.128 * side)
			contact.y = ceiling_y + .001
			var bearing := false
			for ceiling in ceilings:
				if ceiling.grow(.002).has_point(contact):
					bearing = true
					break
			carried = carried and bearing
		if not carried: continue
		var duplicate := false
		for station in stations:
			if station.origin.distance_to(at) < .25:
				duplicate = true
				break
		if not duplicate: stations.append(Transform3D(basis,at))

func draw(parent: Node3D) -> void:
	parent.set_meta("hanger_stations", stations.duplicate())
	if stations.is_empty(): return
	var template := MODEL.instantiate() as Node3D
	for part: MeshInstance3D in template.find_children("*", "MeshInstance3D", true, false):
		var draw := MultiMeshInstance3D.new()
		draw.name = "Hangers_" + str(part.name)
		draw.material_override = MatLib.get_mat(str(part.name))
		draw.multimesh = MultiMesh.new()
		draw.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		draw.multimesh.mesh = part.mesh
		draw.multimesh.instance_count = stations.size()
		for index in stations.size():
			draw.multimesh.set_instance_transform(index, stations[index] * part.transform)
		parent.add_child(draw)
	template.free()

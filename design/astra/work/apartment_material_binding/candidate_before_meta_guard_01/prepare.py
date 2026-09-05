"""Prepare only; never writes game/, launches an engine, or changes a baseline."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
RELATIVE = 'game/scripts/reality/apartment_encroachment.gd'
source = ROOT / RELATIVE
original = source.read_bytes()
text = original.decode('utf-8').replace('\r\n', '\n')

def replace_once(old, new):
    global text
    if text.count(old) != 1:
        raise RuntimeError(f'Expected exactly one source anchor: {old[:100]!r}')
    text = text.replace(old, new)

replace_once('var storey_materials: Dictionary = {}',
    'var storey_materials: Dictionary = {}')
replace_once('\t\t\tvar mi := node as MeshInstance3D\n\t\t\tif mi.mesh == null or not mi.name.contains("_finish_"):',
    '\t\t\tvar mi := node as MeshInstance3D\n\t\t\tif not _living_candidate(mi, floor_node):\n\t\t\t\tcontinue\n\t\t\tif mi.mesh == null or not mi.name.contains("_finish_"):')
replace_once('\t\t\t\tvar material := _material_for(original, plates, rect, floor_y)\n',
    '\t\t\t\tvar material := _material_for(original, plates, rect, floor_y)\n'
    '\t\t\t\t# This unique case material is also retained by the finish refresh row.\n'
    '\t\t\t\tmaterial.set_meta("living_storey", floor_id)\n')
start = text.index('func _bind_storey(')
end = text.index('\n\nfunc _bind_living(', start)
text = text[:start] + '''func _bind_storey(floor_node: Node, floor_id: String, _field) -> void:
	# Seed only weak source aliases from the previous active set. The registry
	# itself is rebuilt; replaced or detached draws cannot accumulate here.
	var copies: Dictionary = {}
	for previous in storey_materials.get(floor_id, []):
		var material := previous as ShaderMaterial
		if material == null or material.has_meta("encroachment_case") \\
				or str(material.get_meta("living_storey", "")) != floor_id:
			continue
		var source_ref := material.get_meta("living_source", null) as WeakRef
		if source_ref != null and source_ref.get_ref() != null:
			copies[source_ref.get_ref()] = material
	if not storey_materials.has(floor_id):
		storey_materials[floor_id] = []
	else:
		(storey_materials[floor_id] as Array).clear()
	for node in floor_node.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not _living_candidate(mi, floor_node) or mi.mesh == null:
			continue
		var over := mi.material_override as ShaderMaterial
		if _is_living_surface(over):
			over = _storey_material(over, floor_id, copies)
			mi.material_override = over
			_bind_living(over, floor_id)
			continue
		# A full override hides the mesh's surface overrides.
		if mi.material_override != null:
			continue
		for s in mi.mesh.get_surface_count():
			var material := mi.get_surface_override_material(s) as ShaderMaterial
			if not _is_living_surface(material):
				continue
			# Preserve SurfacePass's first-owner cache reference (including its
			# governor budget writes); only another storey needs a copy here.
			if not material.has_meta("living_storey"):
				material.set_meta("living_storey", floor_id)
			material = _storey_material(material, floor_id, copies)
			mi.set_surface_override_material(s, material)
			_bind_living(material, floor_id)
	# Case props can be direct children of BuildingRoot rather than the glTF
	# storey. Keep their exact installed material in the same refresh owner.
	for case_id in prop_rows:
		if _floor_of(case_id) != floor_id:
			continue
		for row in prop_rows[case_id]:
			var mi := row.mesh as MeshInstance3D
			if not is_instance_valid(mi) or not _living_candidate(mi, get_parent()):
				continue
			var material := row.material as ShaderMaterial
			if mi.material_override != material or not _is_living_surface(material):
				continue
			material = _storey_material(material, floor_id, copies)
			mi.material_override = material
			row.material = material
			_bind_living(material, floor_id)
	print("[ENCROACH] living field on %s binds %d materials" % [floor_id, storey_materials[floor_id].size()])


func _storey_material(material: ShaderMaterial, floor_id: String, copies: Dictionary) -> ShaderMaterial:
	if str(material.get_meta("living_storey", "")) == floor_id:
		return material
	if copies.has(material):
		return copies[material] as ShaderMaterial
	# Full overrides keep their existing per-storey copy policy; foreign
	# owners must also be copied even when living_storey metadata exists.
	var own := material.duplicate() as ShaderMaterial
	own.set_meta("living_storey", floor_id)
	own.set_meta("living_source", weakref(material))
	copies[material] = own
	return own


static func _is_living_surface(material: ShaderMaterial) -> bool:
	return material != null and material.shader != null \\
			and material.shader.resource_path.get_file().begins_with("orison_surface")


static func _living_candidate(mi: MeshInstance3D, scope: Node) -> bool:
	if not is_instance_valid(mi) or not is_instance_valid(scope):
		return false
	var cursor: Node = mi
	while cursor != null:
		if cursor.is_queued_for_deletion() or cursor is SubViewport or cursor is CharacterBody3D \\
				or cursor.is_in_group("resident_placeholders") or cursor.is_in_group("animated_residents") \\
				or str(cursor.name).begins_with("NPC_"):
			return false
		if cursor == scope:
			return true
		cursor = cursor.get_parent()
	return false
''' + text[end:]
replace_once('\t\t\tvar mi := node as MeshInstance3D\n\t\t\tif mi.mesh == null or not (mi.material_override is ShaderMaterial):',
    '\t\t\tvar mi := node as MeshInstance3D\n\t\t\tif not _living_candidate(mi, root):\n\t\t\t\tcontinue\n\t\t\tif mi.mesh == null or not (mi.material_override is ShaderMaterial):')
replace_once('\t\t\town.set_meta("encroachment_case", case_id)\n',
    '\t\t\town.set_meta("encroachment_case", case_id)\n'
    '\t\t\town.set_meta("living_storey", _floor_of(case_id))\n')

candidate = text.encode('utf-8')
for folder, data in [('originals', original), ('proposed', candidate)]:
    destination = HERE / folder / RELATIVE
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
patch = ''.join(difflib.unified_diff(original.decode('utf-8').replace('\r\n', '\n').splitlines(True),
    text.splitlines(True), fromfile='a/' + RELATIVE, tofile='b/' + RELATIVE))
(HERE / 'apartment_material_binding.patch').write_text(patch, encoding='utf-8', newline='\n')
sha = lambda data: hashlib.sha256(data).hexdigest()
(HERE / 'preparation.json').write_text(json.dumps({
    'schema': 'astra.apartment_material_binding.preparation.v1',
    'status': 'outside_game_not_executed', 'production_path': RELATIVE,
    'original_sha256': sha(original), 'proposed_sha256': sha(candidate),
    'patch_sha256': sha(patch.encode()),
    'scope': 'registration/ownership only; no reach_props candidate collection or spatial preselection rewrite',
    'engine_runs': 0, 'live_writes': 0,
}, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'original_sha256': sha(original), 'proposed_sha256': sha(candidate)}))

extends Node
## Ink keyline around the small part under the aim point or in the hand.
##
## An overlay pass only: no mesh, material or owner state is replaced, and the
## part is restored the moment the aim leaves it. Thin sheets, skinned cloth and
## whole leaves are left to the reticle, because an inverted hull paints their
## entire back face instead of drawing an edge.
const LARGEST := .60
const GROW := .0032
const NEUTRAL := Color(.95,.91,.80)

var part: Node3D
var _draws: Array[MeshInstance3D] = []
var _material := StandardMaterial3D.new()

func _init() -> void:
	_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode=BaseMaterial3D.CULL_FRONT
	_material.grow=true
	_material.grow_amount=GROW
	_material.disable_receive_shadows=true

func present(next: Variant,tint: Color) -> void:
	var wanted: Node3D=next as Node3D if next is Node3D and is_instance_valid(next) else null
	_material.albedo_color=Color(tint.r,tint.g,tint.b) if tint.a>0. else NEUTRAL
	if wanted==part and (part==null or is_instance_valid(part)):return
	clear()
	if wanted==null:return
	var found: Array[MeshInstance3D]=[]
	if wanted is MeshInstance3D:found.append(wanted)
	for node: Node in wanted.find_children("*","MeshInstance3D",true,false):found.append(node as MeshInstance3D)
	if found.is_empty() or found.size()>24:return
	for draw: MeshInstance3D in found:
		if draw.mesh==null or draw.skin!=null or draw.material_overlay!=null:return
		var size:=draw.get_aabb().size*draw.global_basis.get_scale().abs()
		if maxf(size.x,maxf(size.y,size.z))>LARGEST or minf(size.x,minf(size.y,size.z))<.003:return
	part=wanted
	for draw: MeshInstance3D in found:
		draw.material_overlay=_material
		_draws.append(draw)

func clear() -> void:
	for draw: MeshInstance3D in _draws:
		if is_instance_valid(draw) and draw.material_overlay==_material:draw.material_overlay=null
	_draws.clear()
	part=null

func outlined() -> bool:
	return not _draws.is_empty()

func _exit_tree() -> void:
	clear()

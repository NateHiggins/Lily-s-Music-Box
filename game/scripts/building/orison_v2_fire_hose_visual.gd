extends Node3D
## Baked flexible hose variants read the original apparatus; no state or verb owner.
var actor: FireLineCabinetProp
var stocks: Dictionary
var lead: MeshInstance3D
var tail: MeshInstance3D
var _pose := ""
func configure(owner_actor: FireLineCabinetProp,meshes: Dictionary) -> void:
	actor = owner_actor; stocks = meshes
	lead = MeshInstance3D.new(); lead.name = "NativeOutletHose"; add_child(lead)
	tail = MeshInstance3D.new(); tail.name = "NativeNozzleHose"; add_child(tail)
	_process(0)
func _process(_delta: float) -> void:
	if actor == null: return
	var signature := "%d%d%d" % [int(actor.folds_fresh),int(not actor.coupling_made_up),int(actor.nozzle_coupled)]
	if signature == _pose: return
	_pose = signature
	lead.mesh = stocks["HoseLead" + signature.left(2)]
	tail.mesh = stocks["HoseTail" + signature[0] + signature[2]]

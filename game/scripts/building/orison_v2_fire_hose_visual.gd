extends Node3D
## Baked flexible hose variants read the original apparatus; no state or verb owner.
var actor: FireLineCabinetProp
var stocks: Dictionary
var lead: MeshInstance3D
var tail: MeshInstance3D
var _pose := ""
var _stock_library: RefCounted
var _live_lead: MeshInstance3D
var _failed_pose := false
func configure(owner_actor: FireLineCabinetProp,meshes: Dictionary) -> bool:
	actor = owner_actor; stocks = meshes
	lead = MeshInstance3D.new(); lead.name = "NativeOutletHose"; add_child(lead)
	tail = MeshInstance3D.new(); tail.name = "NativeNozzleHose"; add_child(tail)
	if actor.has_method("flexible_outlet_hose_points"):
		_stock_library=preload("res://scripts/props/fire_hose_stock_library.gd").new()
		if not _stock_library.load_stock():return false
		_live_lead=_stock_library.make_hose("OutletStock",stocks.HoseLead00.surface_get_material(0))
		if _live_lead==null:return false
		_live_lead.name="ContinuousNativeOutletHose";add_child(_live_lead)
	_process(0)
	return not _failed_pose
func _process(_delta: float) -> void:
	if actor == null: return
	var nozzle_pose: int=int(actor.call("nozzle_hose_pose")) if actor.has_method("nozzle_hose_pose") else int(actor.nozzle_coupled)
	var signature := "%d%d%d" % [int(actor.folds_fresh),int(not actor.coupling_made_up),nozzle_pose]
	if signature != _pose:
		_pose = signature
		lead.mesh = stocks["HoseLead" + signature.left(2)]
		tail.mesh = stocks["HoseTail" + signature[0] + signature[2]]
	if _live_lead!=null:
		var points: Dictionary=actor.flexible_outlet_hose_points()
		# Legacy maintenance pose fixtures can tilt the old coupling. They
		# retain their original baked pose until the loose joint is migrated.
		_live_lead.visible=bool(points.upright);lead.visible=not _live_lead.visible
		if _live_lead.visible and not _live_lead.pose(points.first,points.last):
			if not _failed_pose:push_error("Native outlet hose cannot reach its physical endpoints")
			_failed_pose=true

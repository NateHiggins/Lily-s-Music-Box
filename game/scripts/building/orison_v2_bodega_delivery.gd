extends Node3D
## The morning's delivery on the bodega's handcart in the back alcove. Lily's ruling
## cam_restock_run_20261124: Cam brings the day's delivery by handcart at dawn and
## every delivery lands at 04:00 (on the Triangle fire date a carter brings it
## unseen). The load stands on the handcart from the delivery until the shop has
## unpacked it. Presentation only: ShopStock keeps the units and the calendar, and
## this owner never changes them. A slow timer, not a per-frame poll.

## Minutes of the local day: the delivery lands, then the shelves are filled.
const DELIVERED := 240.0
const UNPACKED := 420.0
const POLL_SECONDS := 5.0
## Shop-local crates on the handcart bed (the authored base's top is at y 0.34).
const CRATES := [
	[Vector3(0.50, 0.30, 0.40), Vector3(-0.76, 0.49, -9.55)],
	[Vector3(0.48, 0.28, 0.38), Vector3(-0.76, 0.48, -9.12)],
	[Vector3(0.44, 0.24, 0.36), Vector3(-0.76, 0.76, -9.56)],
]
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")

var load_node: Node3D
var _clock := CampaignClock.new()
var _timer: Timer


static func loaded_at(minute_of_day: float) -> bool:
	return minute_of_day >= DELIVERED and minute_of_day < UNPACKED


func _ready() -> void:
	load_node = Node3D.new()
	load_node.name = "DeliveryLoad"
	add_child(load_node)
	var timber := MatLib.get_mat("timber").duplicate() as StandardMaterial3D
	timber.uv1_triplanar = false
	timber.uv1_scale = Vector3.ONE / float(MatLib.SETS["timber"][3])
	for row: Array in CRATES:
		var box := BoxMesh.new()
		box.size = row[0]
		var draw := MeshInstance3D.new()
		draw.name = "Crate"
		draw.mesh = MetreUV.chart(box)
		draw.material_override = timber
		draw.position = row[1]
		load_node.add_child(draw)
	_timer = Timer.new()
	_timer.wait_time = POLL_SECONDS
	_timer.autostart = true
	_timer.timeout.connect(refresh)
	add_child(_timer)
	refresh()


func refresh() -> void:
	if load_node == null:
		return
	load_node.visible = _clock.bind_state() and loaded_at(_clock.minute_of_day())

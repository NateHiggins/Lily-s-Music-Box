extends "res://scripts/props/laundry_bundle.gd"
## Lena's end of the Model Laundry counter. The folded coat slides along the top to her and comes
## back the next day, the same as the wash. She stands here when the timetable says so, appearing
## and leaving only while the player is out of the room. Her book and ticket stay in her own threads.

const RESIDENT := "lena_ortiz"
const PLACE := "hand_laundry"
const POLL_SECONDS := 5.0
const NEARBY := 30.0
const ROOM := Rect2(4.0, -44.7, 7.0, 5.4)
const STANCE := [9.35, -39.65, 0.0]
const FACING := -PI * 0.5

var runtime: Node3D
var lena: Node3D
var _poll := 0.0


func _init() -> void:
	job = LaundrySales.MENDING_KEY
	model_path = "res://assets/props/mending_fold.glb"
	part_keys = {"coat": "fabric_warm", "ticket": "paper"}
	axis = Vector3.FORWARD
	gesture = Vector2.LEFT


func _process(delta: float) -> void:
	super(delta)
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_SECONDS
	var player := get_tree().get_first_node_in_group("player_controller") as Node3D
	if player == null or player.global_position.distance_to(global_position) > NEARBY or _player_in_room(player):
		return
	attend()


func _player_in_room(player: Node3D) -> bool:
	var at: Vector3 = runtime.passage_region.to_local(player.global_position)
	return ROOM.has_point(Vector2(at.x, -at.z))


## Puts her body where the timetable has her.
func attend() -> void:
	var here := str(runtime.resident_whereabouts(RESIDENT).get("place", "")) == PLACE
	if here and lena == null:
		_stand()
	elif not here and lena != null:
		lena.queue_free()
		lena = null


func _stand() -> void:
	var presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
	for row: Dictionary in presentation.roster():
		if str(row.id) == RESIDENT:
			lena = presentation.new()
			lena.setup(str(row.display), RESIDENT, str(row.unit), str(row.model))
	if lena == null:
		return
	lena.externally_driven = true
	lena.face_interacting_player = true
	runtime.passage_region.transaction_actor_root().add_child(lena)
	lena.global_transform = runtime.passage_region.global_transform * Transform3D(Basis(Vector3.UP, FACING), GameBoot.b2g(STANCE))
	lena._play_named("idle")

class_name DreamBoundaryWakingStub
extends Node3D
## Lightweight waking world for N4's real-file transaction proof. Domain
## owners are real; only the eight-floor rendered building is omitted.

class StubPlayer:
	extends CharacterBody3D
	var call_locked := false
	var stable_floor := true
	var onset_progress := 0.0

	func sleep_entry_body_is_stable() -> bool:
		return stable_floor

	func set_sleep_onset_progress(value: float) -> void:
		onset_progress = value


class StubSafetyGate:
	extends Node
	var blocked := false

	func blocks_sleep_entry(_world_position: Vector3) -> bool:
		return blocked

const RESIDUE_ID := "mina_factual_refrigerator_caption"

var work_orders: WorkOrders
var inventory: MaintenanceInventory
var player: StubPlayer
var elevator_gate: StubSafetyGate
var traffic_gate: StubSafetyGate
var core_loop: CoreLoopDirector
var layout := {"floors": [{"id": "F04", "z": 9.6, "furniture": [{
		"id": "bed", "rect": [-7.2, 3.5, -5.9, 4.4]
}]}]}


func _ready() -> void:
	add_to_group("waking_world")
	work_orders = WorkOrders.new()
	work_orders.name = "WorkOrders"
	work_orders.setup(null)
	work_orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(work_orders)
	inventory = MaintenanceInventory.new()
	inventory.name = "MaintenanceInventory"
	inventory.setup()
	add_child(inventory)
	player = StubPlayer.new()
	player.name = "Player"
	add_child(player)
	elevator_gate = StubSafetyGate.new()
	elevator_gate.name = "ElevatorGate"
	add_child(elevator_gate)
	traffic_gate = StubSafetyGate.new()
	traffic_gate.name = "TrafficGate"
	add_child(traffic_gate)
	var shell := get_tree().get_first_node_in_group(
			"campaign_shell") as CampaignShell
	assert(shell != null and shell.is_ancestor_of(self))
	core_loop = shell.bind_waking_services(work_orders, player, layout,
			elevator_gate, traffic_gate)
	if not core_loop.wake_completed.is_connected(_on_wake_completed):
		core_loop.wake_completed.connect(_on_wake_completed)
	# Same idempotent boot/load reconciliation as MinaCaptionManifestation.
	if core_loop.boundary() == "wake_complete":
		_apply_residue()


func _on_wake_completed(_anchor_id: String) -> void:
	_apply_residue()


func _apply_residue() -> void:
	RealityState.apply_waking_residue(RESIDUE_ID, {
		"case_id": "mina_caption_crisis",
		"source_job_id": ChirpHunt.JOB_ID,
		"anchor_id": "F02_2A_FRIDGE_01",
		"display_socket_id": "2A_FRIDGE_FACE",
		"text": "REFRIGERATOR",
	})

extends Node
## Optional V2 presentation driver. The player's logical switch stays the
## gameplay authority; this replaces, rather than adds to, its old transient.
const State := preload("res://scripts/lamp/lamp_optical_state.gd")
const Snapshot := preload("res://scripts/lamp/lamp_optical_snapshot.gd")
var state := State.new()
var player: PlayerController
var output: Dictionary = {}

func setup(owner_player: PlayerController) -> bool:
	player = owner_player
	var saved: Variant = RealityState.data.get("lamp_optics")
	if saved != null:
		if not Snapshot.valid(saved): return false
		state.restore_state(saved)
	else:
		state.configure(0x28A11CE,player.lamp_is_enabled())
	player.lamp_presentation = self
	player.set_lamp_enabled(state.switched_on)
	player.mechanical_stimulus.connect(_on_shock)
	RealityState.snapshot_preparing.connect(_capture_snapshot)
	apply_output()
	return true

func set_powered(on: bool) -> void:
	state.switched_on = on

func advance_frame(delta: float) -> void:
	state.advance(delta)
	apply_output()

func apply_output() -> void:
	state.write_output(output)
	player.flashlight.visible = float(output.intensity) > .001
	player.flashlight.light_energy = player._lamp_base_energy * float(output.intensity)
	player.flashlight.light_color = output.color
	player.flashlight.spot_angle = float(output.cone_angle_deg)
	player.flashlight.light_projector = null
	if is_instance_valid(player.carried_device) and player.carried_device.has_method("set_lamp_optical_output"):
		player.carried_device.set_lamp_optical_output(output.color,float(output.filament_emission))

func _on_shock(_where: Vector3, _carrier: StringName, strength: float,
		_direction: Vector3, _duration: float, _substrate: StringName) -> void:
	state.apply_mechanical_shock(strength)

func _capture_snapshot() -> void:
	# CampaignShell keeps exactly one world in the tree. A cutaway camera must
	# not suppress the live lamp's save. No per-frame allocation or commit.
	if is_inside_tree() and is_instance_valid(player) and player.is_inside_tree() \
			and not player.is_queued_for_deletion():
		RealityState.data.lamp_optics = state.save_state()

func _exit_tree() -> void:
	if is_instance_valid(player) and player.lamp_presentation == self:
		player.lamp_presentation = null

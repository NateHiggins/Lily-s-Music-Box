extends AudioStreamPlayer
## The player's own steps, one per stride the controller measures. How loud they are is
## what's on the feet (ShoeSales). The one recording is a run of real footsteps, played a
## step at a time from the moments each one lands.

const STREAM := "res://assets/audio/freesound/processed/events/stairs_footsteps.ogg"
const STEPS: Array[float] = [19.736, 20.114, 20.457, 24.87, 25.313, 25.826, 26.415, 28.184, 28.73, 29.177, 29.756, 30.351]
const STEP_SECONDS := 0.3
const DECIBELS := {"worn": -13.0, "leather": -8.0, "rubber": -20.0, "slippers": -27.0}

var _left := 0.0


func _ready() -> void:
	stream = load(STREAM)
	bus = "Interaction"


func attach(player: PlayerController) -> void:
	player.mechanical_stimulus.connect(_on_stimulus)


func _on_stimulus(_at: Vector3, kind: StringName, force: float, _direction: Vector3, _radius: float, surface: StringName) -> void:
	if kind != &"impulse" or surface != &"floor":
		return
	volume_db = DECIBELS[ShoeSales.footwear()] + linear_to_db(clampf(force * 2.0, 0.4, 1.0))
	pitch_scale = randf_range(0.94, 1.06)
	play(STEPS[randi() % STEPS.size()])
	_left = STEP_SECONDS


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			stop()

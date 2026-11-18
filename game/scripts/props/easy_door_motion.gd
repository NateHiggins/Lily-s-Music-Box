extends RefCounted
## Cabinet hand-binding compatibility only. Passage movement belongs to the
## player/NPC motors; actual return hardware owns automatic closing.
var door: Node3D
var holder: WeakRef
var closing := false
var remaining := 0.0

func _init(owner_node: Node3D) -> void:
	door = owner_node

func bind_holder(actor: Node3D) -> void:
	holder = weakref(actor)
	stop()

func prepare_motion() -> void:
	pass # Never remove the leaf from player or carried-stock collision.

func accommodate(_angle: float) -> void:
	pass # A door command must not push or teleport the character.

func stop() -> void:
	closing = false
	remaining = 0.0
	door.set_physics_process(false)

func schedule() -> void:
	stop() # A leaf without a return mechanism stays where it was left.

func update(_delta: float) -> void:
	stop()

func release() -> void:
	holder = null

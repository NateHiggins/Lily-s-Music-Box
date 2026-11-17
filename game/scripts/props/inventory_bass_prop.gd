extends StaticBody3D
## One original world projection; inventory items have no carrying physics.
var _home := Transform3D.IDENTITY
var _bound := false

func bind_inventory_placement() -> void:
	_home=global_transform
	_bound=true
	RealityState.state_changed.connect(_sync_inventory)
	_sync_inventory()

func _sync_inventory() -> void:
	if not _bound:return
	var stowed:=PersonInventory.object_location()=="inventory"
	visible=not stowed
	collision_layer=0 if stowed else 1
	collision_mask=0 if stowed else 1
	for shape: CollisionShape3D in find_children("*","CollisionShape3D",false,false):shape.set_deferred("disabled",stowed)
	global_transform=_home

func interact_prompt() -> String:
	return "Put away the bass" if visible else ""

func interact(_player: Node) -> void:
	PersonInventory.set_object_location(PersonInventory.object_holder(),"inventory")

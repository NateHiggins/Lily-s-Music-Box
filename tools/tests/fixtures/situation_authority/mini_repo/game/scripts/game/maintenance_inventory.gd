extends Node
## Inventory authority: the rightful custody owner.

var data := {}


func acquire(item: String) -> void:
	data.part_custody = item


func consume(item: String) -> void:
	data.consumed_at = Time.get_unix_time_from_system()
	RealityState.commit()

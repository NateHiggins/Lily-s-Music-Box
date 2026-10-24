extends "res://scripts/props/entrance_marquee_dress.gd"
## The V2 marquee is dark. Its soffit lamps, pavement pool, fascia troughs,
## return grazers and sign trough are gone (owner, 2026-10-24: a foreboding
## entrance). The prismatic tray reads black from the street, the bronze
## legend shows only where street light reaches it, and the one lamp at the
## door is the entry vestibule's gas lantern. Knee frames and the look-point stay.

func _ready() -> void:
	name = "EntranceMarqueeDress"
	_nameplate()
	# Keep the legend; retire the trough that lit it, and let the letters
	# take light like the bronze they are cut into.
	for child: Node in get_children():
		if child is Light3D:
			remove_child(child)
			child.free()
		elif child is Label3D:
			(child as Label3D).shaded = true
	_build_interaction()


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("marquee",{
		"roof_state":"PRISMATIC GLASS TRAY / RAIN SHEDDING",
		"bracket_state":"IRON RETURNS AND PIER KNEE FRAMES SEATED",
		"light_state":"TRAY LAMPS OUT OF THEIR SOCKETS / FASCIA DARK / GAS LANTERN AT THE DOOR",
	})

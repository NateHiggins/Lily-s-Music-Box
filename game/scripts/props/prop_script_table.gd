extends RefCounted
## Which script builds each prop kind. It lived in the V1 building root as
## PROP_SCRIPTS; V2's debug prop warehouse and the warehouse shot read it too,
## so it stands apart from either building (V1 retirement plan, section 4).

const TABLE := {
	"radiator": preload("res://scripts/props/radiator_prop.gd"),
	"lamp": preload("res://scripts/props/lamp_prop.gd"),
	"washer": preload("res://scripts/props/washer_prop.gd"),
	"laundry_airer": preload("res://scripts/props/laundry_airer_prop.gd"),
	"boiler": preload("res://scripts/props/boiler_prop.gd"),
	"toaster": preload("res://scripts/props/toaster_prop.gd"),
	"fridge": preload("res://scripts/props/fridge_prop.gd"),
	"stove": preload("res://scripts/props/stove_prop.gd"),
	"monitor": preload("res://scripts/props/monitor_prop.gd"),
	"signal_terminal": preload("res://scripts/props/signal_terminal_prop.gd"),
	"boxfan": preload("res://scripts/props/boxfan_prop.gd"),
	"door_anomaly": preload("res://scripts/props/door_anomaly_prop.gd"),
	"case_door": preload("res://scripts/props/case_door_prop.gd"),
	"speaker": preload("res://scripts/props/speaker_prop.gd"),
	"flue_breast": preload("res://scripts/props/flue_breast_prop.gd"),
	"porch_deck": preload("res://scripts/props/porch_deck_prop.gd"),
	"kettle": preload("res://scripts/props/kettle_prop.gd"),
	"wall_clock": preload("res://scripts/props/clock_prop.gd"),
	"vantry_point": preload("res://scripts/props/vantry_point_prop.gd"),
	"exhaust_fan": preload("res://scripts/props/exhaust_fan_prop.gd"),
	"ceiling_light": preload("res://scripts/props/ceiling_light_prop.gd"),
	"pendant_shade": preload("res://scripts/props/light_fixture_prop.gd"),
	"flush_dome": preload("res://scripts/props/light_fixture_prop.gd"),
	"sconce_globe": preload("res://scripts/props/light_fixture_prop.gd"),
	"kitchen_linear": preload("res://scripts/props/light_fixture_prop.gd"),
	"cage_bulb": preload("res://scripts/props/light_fixture_prop.gd"),
	"chandelier": preload("res://scripts/props/light_fixture_prop.gd"),
	"eye_pendant": preload("res://scripts/props/light_fixture_prop.gd"),
	# Spawned from `furniture`, not from a marker, so nothing here will ever
	# instantiate it for the building - it is registered so the inspection shed
	# can show the four chassis. See arcade_row.gd for how the real ones arrive.
	"arcade_cabinet": preload("res://scripts/props/arcade_cabinet_prop.gd"),
	"neon_sign": preload("res://scripts/props/neon_sign_prop.gd"),
	"bodega_signage": preload("res://scripts/props/bodega_signage_prop.gd"),
	"bar_signage": preload("res://scripts/props/harukiya_signage_prop.gd"),
	"shop_sign": preload("res://scripts/props/shop_sign_prop.gd"),
	"sink": preload("res://scripts/props/tap_prop.gd"),
	"shower": preload("res://scripts/props/tap_prop.gd"),
	"mirror": preload("res://scripts/props/medicine_cabinet_prop.gd"),
	"street_lamp": preload("res://scripts/props/light_fixture_prop.gd"),
	"songbook_terminal": preload(
			"res://scripts/props/songbook_terminal_prop.gd"),
	"darts": preload("res://scripts/props/darts_prop.gd"),
	"point_ball": preload("res://scripts/props/point_ball_prop.gd"),
	# Architectural hardware has no layout marker, but the warehouse registry
	# is a catalog of things worth judging, not only things marker-spawned.
	"mail_bank": preload("res://scripts/props/mail_bank_prop.gd"),
	# Plain Node3D actors can opt into warehouse inspection without pretending
	# to be networked FunctionalProps. Runtime door markers are still handled
	# by the dedicated branch below, so this is inspection registration only.
	"door": preload("res://scripts/props/door_prop.gd"),
	"landmark_entry": preload("res://scripts/props/landmark_entry_door.gd"),
	"bookshelf": preload("res://scripts/props/bookshelf_prop.gd"),
}

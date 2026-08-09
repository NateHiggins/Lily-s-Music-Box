class_name BoilerTend
extends Node
## One slow clock for the plant. BoilerProp owns the physical facts; this
## director carries their consequence to the radiator budget and hot taps.
## It never invents fuel or heat, and it keeps running while nobody is looking.

var boiler: BoilerProp
var heat_balance
var taps: Array[TapProp] = []
var _accum := 0.0


func configure(plant: BoilerProp, balance, water_fixtures: Array[TapProp]) -> void:
	boiler = plant
	heat_balance = balance
	taps = water_fixtures
	if boiler:
		boiler.boiler_state_changed.connect(_on_boiler_state_changed)
		_publish(boiler.get_boiler_state())


func _process(delta: float) -> void:
	if boiler == null or not is_instance_valid(boiler):
		return
	_accum += delta
	if _accum < 1.0:
		return
	var elapsed := _accum
	_accum = 0.0
	boiler.tick_plant(elapsed)


func _on_boiler_state_changed(plant_state: Dictionary) -> void:
	_publish(plant_state)


func _publish(plant_state: Dictionary) -> void:
	var output := float(plant_state.get("output", 0.0))
	if heat_balance and heat_balance.has_method("set_boiler_output"):
		heat_balance.set_boiler_output(output)
	# The domestic hot-water curve is deliberately not identical to radiator
	# output: a weak fire still gives tepid water before the radiators go cold.
	var hot_water := clampf(0.18 + output * 0.82, 0.0, 1.0)
	for tap in taps:
		if is_instance_valid(tap):
			tap.set_boiler_temperature(hot_water)

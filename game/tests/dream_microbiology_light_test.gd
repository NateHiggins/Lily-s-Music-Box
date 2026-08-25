extends Node
## MBIO-1 focused contract: finite-speed microbial light response.

const MicroLight := preload("res://scripts/dream/dream_microbiology_light.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	_run()


func _run() -> void:
	var pose := {
		"origin": Vector3.ZERO,
		"dir": Vector3.FORWARD,
		"range": 8.0,
		"angle_deg": 50.0,
		"energy": 0.74,
		"splash": Vector3(0.0, 0.0, -6.0),
	}
	var centre := MicroLight.sample(pose, Vector3(0.0, 0.0, -2.0))
	_check("the centre of the real cone drives a receptor", float(centre.level) > 0.55)
	_check("the sample retains a direction toward the source",
			(centre.toward as Vector3).dot(Vector3.BACK) > 0.99)
	_check("outside the cone is dark",
			float(MicroLight.sample(pose, Vector3(4.0, 0.0, -2.0)).level) == 0.0)
	var off := pose.duplicate()
	off.energy = 0.0
	_check("lamp off is stimulus off",
			float(MicroLight.sample(off, Vector3(0.0, 0.0, -2.0)).level) == 0.0)
	var stopped := pose.duplicate()
	stopped.splash = Vector3(0.0, 0.0, -1.0)
	_check("the lamp's production hit stops sensing through a wall",
			float(MicroLight.sample(stopped, Vector3(0.0, 0.0, -2.0)).level) == 0.0)

	# Slow entry changes the adapted baseline in small increments; no single
	# membrane step is large enough to become a photoshock.
	var slow := MicroLight.state()
	var slow_shocks := 0
	for i in 80:
		var level := 0.75 * float(i + 1) / 80.0
		if MicroLight.advance(slow, level, 0.05):
			slow_shocks += 1
	_check("slow beam entry orients without photoshock", slow_shocks == 0)
	_check("slow entry still establishes adapted light memory", float(slow.adapted) > 0.25)
	_check("the receptor scan advances under contrast", float(slow.scan) > 0.0)

	var abrupt := MicroLight.state()
	var first := MicroLight.advance(abrupt, 0.78, 0.05)
	var first_peak := float(abrupt.shock)
	_check("abrupt switch-on admits one photoshock", first and int(abrupt.shocks) == 1)
	_check("photoshock creates a strong motor response", float(abrupt.response) > 0.8)
	MicroLight.advance(abrupt, 0.0, 0.08)
	var refused := MicroLight.advance(abrupt, 0.78, 0.08)
	_check("refractory tissue refuses immediate flicker",
			not refused and int(abrupt.shocks) == 1)

	# Sustained light becomes background rather than an endless alarm.
	var early_response := float(abrupt.response)
	for i in 80:
		MicroLight.advance(abrupt, 0.78, 0.05)
	_check("sustained light adapts", float(abrupt.adapted) > 0.60)
	_check("sustained response falls below onset", float(abrupt.response) < early_response)

	# Give the membrane enough dark time to admit a second event, but not
	# enough to regain full sensitivity. This is the unreliable-lamp beat.
	for i in 34:
		MicroLight.advance(abrupt, 0.0, 0.05)
	var second := MicroLight.advance(abrupt, 0.78, 0.05)
	_check("a recovered receptor can answer a later lamp step", second)
	_check("the later answer is weaker than the first",
			float(abrupt.shock) < first_peak and float(abrupt.shock) > 0.0)
	_check("the receptor remembers two admitted events", int(abrupt.shocks) == 2)
	_finish()


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[PASS] ", label)
	else:
		failures += 1
		push_error("[FAIL] " + label)


func _finish() -> void:
	print("\nDreamMicrobiologyLightTest: %d/%d passed" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)

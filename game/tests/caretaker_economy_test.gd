extends Node
var failures := 0

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var orders := WorkOrders.new()
	add_child(orders)
	orders.setup(null)
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	var wallet := preload("res://scripts/game/caretaker_economy.gd").new()
	add_child(wallet)
	_check(wallet.setup(orders),"wallet binds authoritative job owner")
	var identity := "vantry_chirp_2a"
	_check(orders.issue_job(identity,"reported"),"authored request issued")
	_check(orders.acknowledge_job(identity),"acknowledged")
	_check(orders.diagnose_job(identity),"diagnosed")
	_check(orders.mark_job_awaiting_part(identity),"part required")
	_check(orders.mark_job_repairable(identity),"repairable")
	_check(orders.record_job_repair(identity,{"quality":"good","note":"tested"}),"repair recorded")
	_check(wallet.book().cash==100,"unfinished request pays no tip")
	RealityState.save_path = "user://tests/economy_"+str(Time.get_ticks_usec())+".json"
	RealityState.persistence_enabled = true
	_check(orders.close_job(identity),"closed through normal lifecycle")
	var cash: int = wallet.book().cash
	_check(cash>100,"closure pays a tip")
	RealityState.load_game()
	_check(wallet.book().cash==cash,"closing snapshot includes tip atomically")
	wallet._settle_jobs()
	_check(wallet.book().cash==cash,"settlement cannot replay after load")
	var before: int = wallet.affection("mina_vale")
	wallet.appreciate("mina_vale")
	_check(wallet.affection("mina_vale")==before,"same-day goodwill bounded")
	RealityState.persistence_enabled = false
	RealityState.data.erase("caretaker_economy")
	_check(wallet.book().cash==100,"legacy campaign receives starting pocket only")
	wallet._settle_jobs()
	_check(wallet.book().cash==100,"legacy closed jobs do not mint retroactive tips")
	RealityState.save_path = RealityState.SAVE_PATH
	print("CARETAKER ECONOMY: failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func _check(ok: bool, words: String) -> void:
	print("ECONOMY ","PASS " if ok else "FAIL ",words)
	if not ok: failures += 1

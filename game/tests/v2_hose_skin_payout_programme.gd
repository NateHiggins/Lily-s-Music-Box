extends "res://tests/v2_hose_right_payout_programme.gd"
var setup_ms:=0.
# Dedicated skin-bend input diagnostic. Release is tested separately and its
# current velocity-solver failure remains in the original full programme log.
func _span_allowance() -> float:return .15
func _input_setup_ms() -> float:return setup_ms
func run(holder: PlayerController) -> bool:
 player=holder;_check_native_density()
 check(_pose_matches(),"native skin starts at its source-owned resting pose")
 var world_checks: RefCounted=_make_world_programme()
 var excluded: Array[RID]=[endpoint.get_rid(),player.get_rid()]
 contact=await world_checks.run(self,rig,excluded)
 for failure: String in world_checks.failures:check(false,failure)
 var configured: int=Time.get_ticks_usec()
 check(tether.configure(rig,contact),"native solver initializes before actual input")
 setup_ms=(Time.get_ticks_usec()-configured)/1000.
 print("HOSE INPUT SETUP MS: ",setup_ms)
 if failures.is_empty():await _payout()
 return failures.is_empty()

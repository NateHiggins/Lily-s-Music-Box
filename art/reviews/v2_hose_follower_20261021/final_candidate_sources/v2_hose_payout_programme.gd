extends "res://tests/v2_hose_follower_programme.gd"
## Isolated actual-input payout diagnostic. No installed rack/nozzle/spray claim.
func run(holder: PlayerController) -> bool:
 if not await super.run(holder):return false
 await _payout()
 return failures.is_empty()
func _direction() -> float:return -1.
func _payout() -> void:
 var saved: Dictionary=rig.snapshot();var player_before: Transform3D=player.global_transform;var eye_before: Transform3D=player.camera.transform
 var pick: Vector3=handle.to_global(Vector3(.022,.004,0))
 player.global_position=pick+Vector3(0,0,.4)-player.camera.position;player.camera.global_basis=Basis.IDENTITY;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 for frame in 3:await get_tree().process_frame
 check(player._grab.find_target().get("part")==handle,"payout starts by targeting the actual native hose-end surface")
 if failures.is_empty():_click()
 check(player._grab.active() and held,"primary click latches the payout fitting")
 var records: Array=[];var target_x: float=rig.strand.anchor.x+_direction()*(rig.strand.total_length-.02)
 for step in 310:
  if not player._grab.active():check(false,"payout grip remains owned");break
  var before: Vector3=rig.strand.points[0]
  if _direction()*(before.x-target_x)>=-.000002:break
  var displacement:=Vector3(_direction()*minf(absf(target_x-before.x),.055),0,0)
  var point: Vector3=handle.to_global(player._grab.contact)
  var relative: Vector2=player.camera.unproject_position(point+displacement)-player.camera.unproject_position(point)
  var motion:=InputEventMouseMotion.new();motion.relative=relative
  var start: int=Time.get_ticks_usec();player._unhandled_input(motion)
  records.append({"step":step,"input_ms":(Time.get_ticks_usec()-start)/1000.,"endpoint":str(rig.strand.points[0]),"solve_ms":tether.last_ms,"error":tether.error,"responses":tether.responses,"blocked":tether.blocked})
  if rig.strand.points[0].distance_to(before)<.000001:
   _save_held_case(before+displacement);check(false,"payout makes physical progress before the material reach limit");break
  # Camera follows the fitting only in this isolated fixture, with player
  # physics disabled. This is explicitly not a played building travel test.
  player.global_position+=rig.strand.points[0]-before
  await get_tree().process_frame
 check(_direction()*(rig.strand.points[0].x-target_x)>=-.000002 and rig.strand._valid_positions(rig.strand.points) and rig.strand.points[-1]==rig.rest[-1],"actual mouse input pays out all15.24m stock to within20mm endpoint-span allowance for fixed neck bends")
 var before_release: PackedVector3Array=rig.strand.points.duplicate()
 if player._grab.active():_click()
 check(not player._grab.active() and not held and rig.strand.points==before_release,"second click releases the paid-out fitting without folding or snapping")
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():FileAccess.open(out.path_join("payout.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Isolated actual-input payout with fixture camera following, no installed travel/rack/nozzle/self-contact/spray qualification.","direction_x":_direction(),"steps":records,"pose":rig.snapshot(),"bind_frames":_frame_rows(rig.original_frames),"frames":_frame_rows(rig.model_frames(rig.strand.points)),"failures":failures},"\t"))
 check(rig.restore(saved),"payout diagnostic restores original pose");_sync()
 player.global_transform=player_before;player.camera.transform=eye_before

func _save_held_case(goal: Vector3) -> void:
 var rows: Array=[];var attempted: Array=[];var current: Array=[]
 for point: Vector3 in tether.kernel.last_input:rows.append([point.x,point.y,point.z])
 for point: Vector3 in tether.kernel.coupled.last_iterate:attempted.append([point.x,point.y,point.z])
 for point: Vector3 in rig.strand.points:current.append([point.x,point.y,point.z])
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():FileAccess.open(out.path_join("held_case.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","error":tether.error,"goal":[goal.x,goal.y,goal.z],"target":rows,"result":attempted,"before":current,"lengths":Array(tether.kernel.lengths),"spans":Array(tether.kernel.bend_spans),"inverse":Array(tether.kernel.inverse),"anchor":[rig.strand.anchor.x,rig.strand.anchor.y,rig.strand.anchor.z]},"\t"))

func _frame_rows(frames: Array[Transform3D]) -> Array:
 var result: Array=[]
 for frame: Transform3D in frames:result.append([[frame.basis.x.x,frame.basis.x.y,frame.basis.x.z],[frame.basis.y.x,frame.basis.y.y,frame.basis.y.z],[frame.basis.z.x,frame.basis.z.y,frame.basis.z.z],[frame.origin.x,frame.origin.y,frame.origin.z]])
 return result

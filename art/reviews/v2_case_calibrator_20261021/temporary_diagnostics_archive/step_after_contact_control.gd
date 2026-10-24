extends "res://scripts/player/player_controller.gd"
## Diagnostic-only: the normal slide establishes a low blocking contact before
## the unchanged capsule/headroom/raised-motion step tests are attempted.
var contact_step_candidate := false
var contact_step_skipped := 0
func _try_step_up(delta: float) -> void:
 if contact_step_candidate:
  var motion:=Vector3(velocity.x,0,velocity.z)*delta
  var low_contact:=false
  for index in get_slide_collision_count():
   var contact:=get_slide_collision(index)
   if contact.get_position().y<=global_position.y+.30 and contact.get_normal().dot(motion)<-.00001:
    low_contact=true;break
  if not low_contact:
   contact_step_skipped+=1;return
 super._try_step_up(delta)

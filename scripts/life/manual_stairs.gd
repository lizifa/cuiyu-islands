extends RefCounted
## Signed travel along the same physical stair route used by the one-tap action.
var actor:CharacterBody3D
var route:Array[Vector3]=[]
var segment:=0
var travel_sign:=1.0
var control_axis:=Vector2.UP
func setup(owner_actor:CharacterBody3D,points:Array[Vector3],index:int=0) -> void:
 actor=owner_actor;control_axis=actor.manual_stair_input.normalized() if actor.manual_stair_input.length()>.1 else Vector2.UP;route=points.duplicate();travel_sign=1;segment=clampi(index,0,route.size()-2)
func tick(delta:float) -> void:
 var a:Vector3=route[segment];var b:Vector3=route[segment+1]
 var tangent:Vector3=b-a;tangent.y=0;tangent=tangent.normalized()
 var input:Vector2=actor.manual_stair_input.limit_length()
 var travel:float=input.dot(control_axis)
 if absf(travel)>.15:travel_sign=signf(travel)
 var target:Vector3=b if travel_sign>=0 else a
 var flat:Vector3=target-actor.position;flat.y=0
 if input.length()>.1 and flat.length()<.13 and absf(target.y-actor.position.y)<.2:
  if travel_sign>0:
   if segment==route.size()-2:actor.finish_stairs(true);return
   segment+=1
  else:
   if segment==0:actor.finish_stairs(false);return
   segment-=1
  return
 if absf(travel)<.15:
  actor.velocity=Vector3.ZERO
  if actor.animator!=null and actor.animator.current_animation!=actor.idle_clip:actor.animator.play(actor.idle_clip,.15)
  return
 var step:Vector3=flat.normalized()
 actor.velocity=step*minf(1.6*absf(travel),flat.length()/maxf(delta,.001))
 if actor.is_on_floor():actor.velocity=actor.velocity.slide(actor.get_floor_normal());actor.velocity.y-=.2
 else:actor.velocity.y=-2
 actor.move_and_slide()
 actor.visual.rotation.y=lerp_angle(actor.visual.rotation.y,atan2(step.x,step.z),1-exp(-10*delta))
 if actor.animator!=null and actor.animator.current_animation!=actor.walk_clip:actor.animator.play(actor.walk_clip,.15)

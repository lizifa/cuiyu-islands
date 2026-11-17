extends "res://scripts/life/companion.gd"
## 悬浮伙伴复用既有交互接口，不运行地面动物步态/跳跃，也不阻挡人物。
var kind:=""
func setup(owner_world:Node3D,value:String) -> void:
 world=owner_world;kind=value
 visual=preload("res://scripts/life/companion_catalog.gd").make_visual(kind,world);add_child(visual)
 collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(.65,.65,.65);collider.shape=shape;collider.disabled=true;add_child(collider)
 collision_layer=0;collision_mask=0
 for animator:AnimationPlayer in visual.find_children("*","AnimationPlayer",true,false):
  animation=animator
  for clip in animator.get_animation_list():
   if "idle" in str(clip).to_lower():
    animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR;animator.play(clip);break
  break
func _goal() -> Vector3:
 var offset=Vector3(.95,.95,.7)
 if world.player.boating:offset=Vector3(.9,1.1,.2)
 elif petting>0:offset=Vector3(.8,.28 if kind=="cloud" else .12,.4)
 elif held_for_interaction:offset=Vector3(1.5,1.0,.8)
 offset=offset.rotated(Vector3.UP,world.player.visual.rotation.y)
 return world.player.position+offset+Vector3.UP*sin(clock*2.2)*(.025 if petting>0 else .08)
func recover() -> void:
 if world==null:return
 activity.reset(self);trail.clear();petting=0;held_for_interaction=false
 position=_safe_goal(_goal());velocity=Vector3.ZERO;visible=true;last_place=world.last_location;last_player=world.player.position
func _safe_goal(target:Vector3) -> Vector3:
 var origin:Vector3=world.player.position+Vector3.UP*.65
 var relative:Vector3=target-world.player.position
 for angle:float in [0.0,PI,-PI*.5,PI*.5]:
  var candidate:Vector3=world.player.position+relative.rotated(Vector3.UP,angle)
  var query=PhysicsRayQueryParameters3D.create(origin,candidate,1,[world.player.get_rid(),get_rid()])
  if get_world_3d().direct_space_state.intersect_ray(query).is_empty():return candidate
 return origin
func _physics_process(delta:float) -> void:
 if world==null or not world.player.allowed:
  if animation!=null:animation.speed_scale=0
  return
 if animation!=null:animation.speed_scale=1
 clock+=delta;petting=maxf(0,petting-delta)
 if last_place!=world.last_location or position.distance_to(world.player.position)>12:recover()
 var target=_safe_goal(_goal())
 var player_speed:float=minf(15.0,world.player.position.distance_to(last_player)/maxf(delta,.001))
 last_player=world.player.position
 var next=position.move_toward(target,delta*maxf(6.5 if world.player.boating else 4.5,player_speed+2.0))
 # 检查自身移动路径，避免绕墙时从墙体内部穿过去。
 var query=PhysicsRayQueryParameters3D.create(position,next,1,[get_rid(),world.player.get_rid()])
 var hit=get_world_3d().direct_space_state.intersect_ray(query)
 position=hit.position+hit.normal*.2 if not hit.is_empty() else next
 velocity=Vector3.ZERO
 if petting<=0:face(lerp_angle(rotation.y,world.player.visual.rotation.y,1-exp(-4*delta)))
func face(heading:float) -> void:rotation.y=heading
func reserve_interaction(_stand:Vector3) -> void:held_for_interaction=true
func release_interaction() -> void:held_for_interaction=false

extends RefCounted
const DURATION:=5.5
static func frame(origin:Vector3,time:float) -> Dictionary:
	var step:float=smoothstep(2.2,3.1,time)
	var actor:Vector3=origin+Vector3(0,0,.65*step)
	var normal_right:Vector3=actor+Vector3(.2,1.25,.48)
	var right:Vector3=normal_right.lerp(actor+Vector3(.3,1,.3),smoothstep(0,.65,time))
	right=right.lerp(actor+Vector3(.1,1.15,.5),smoothstep(.65,1.5,time))
	right=right.lerp(actor+Vector3(.05,1.18,.65),smoothstep(3.1,4.1,time))
	right=right.lerp(actor+Vector3(.25,.85,.2),smoothstep(4.8,DURATION,time))
	var left:Vector3=actor+Vector3(-.2,1.2,.3)
	left=left.lerp(right+Vector3(-.3,.12,.2),smoothstep(1.4,1.8,time))
	if time>1.5 and time<2.2:left+=Vector3(sin(time*19)*.025,sin(time*14)*.02,0)
	left=left.lerp(actor+Vector3(-.15,1,.5),smoothstep(3.1,3.8,time))
	left=left.lerp(actor+Vector3(-.25,.85,.2),smoothstep(4.8,DURATION,time))
	return {"actor":actor,"right":right,"left":left,"step":step,"unhook":smoothstep(1.5,2.2,time),"release":smoothstep(4.1,4.9,time),"return":smoothstep(4.8,DURATION,time)}
static func render(session:Node,time:float) -> void:
	var actor:Node3D=session.app.world.player;var data:Dictionary=frame(session.origin,time)
	var rig:Skeleton3D=actor.pose_skeleton
	var right:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("RightHand")).origin
	var left:Vector3=rig.global_transform*rig.get_bone_global_pose(actor._bone("LeftHand")).origin
	var net_head:Vector3=(session.origin+Vector3(-.55,.55,2)).lerp(right+Vector3(0,.39,.26),smoothstep(.65,1.5,time))
	var park:float=smoothstep(1.5,2.2,time)
	net_head=net_head.lerp(session.origin+Vector3(-1.1,.1,-.25),park)
	var net_grip:Vector3=left.lerp(session.origin+Vector3(-.4,.15,-.55),park)
	session.Landing.place_net(session.net_tool,net_grip,net_head)
	for part:String in ["NetBag","NetMesh"]:session.net_tool.get_node("NetHead/"+part).scale.y=lerpf(1,.18,park)
	session.net_tool.get_node("NetHead/NetBag").position.y=-.325*lerpf(1,.18,park)
	session.rod.position=right.lerp(session.origin+Vector3(.35,1,.25),smoothstep(.45,.8,time));session.rod.basis=Basis.IDENTITY
	session.rod.visible=true;session.line_node.visible=time<2.2
	var keeper:Node3D=session.app.world.fish_keeper
	var mouth:Vector3=keeper.REST.lerp(right+Vector3(0,0,.4),smoothstep(3.1,4.1,time)).lerp(keeper.REST,data["return"])
	keeper.set_mouth(mouth)
	var fish_point:Vector3=(session.origin+Vector3(-.55,.55,2)-Vector3.UP*.27).lerp(right+Vector3(0,.12,.26),smoothstep(.65,1.5,time))
	fish_point=fish_point.lerp(keeper.point_at(data.release*.8),data.release)
	session.fish.visible=time<5.05;session.fish.rotation=Vector3(sin(time*13)*.07,-PI/2,0);session.fish.position=fish_point-session.fish.basis*session.fish_center
	session.Catalog.animate(session.fish,time,true)
	session.bobber.hide();session.ripple.hide()
	if time<.65:session.hint.text="放稳鱼竿 · 准备收鱼"
	elif time<2.2:session.hint.text="托住鱼身 · 轻轻摘钩"
	elif time<4.1:session.hint.text="走近鱼护 · 提起网口"
	else:session.hint.text="将鱼放入鱼护 · 慢慢松手"

import bpy, os
base=os.path.abspath(os.path.join(os.path.dirname(__file__),'../../assets/kenney-protagonists'))
for name,src in [('character','Model/characterMedium.fbx'),('idle','Animations/idle.fbx'),('run','Animations/run.fbx')]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.fbx(filepath=os.path.join(base,src))
 for o in bpy.context.scene.objects:
  print('OBJECT',o.name,o.type,tuple(o.scale),tuple(o.dimensions))
 bpy.ops.export_scene.gltf(filepath=os.path.join(base,name+'.glb'),export_format='GLB',export_animations=True,export_yup=True)

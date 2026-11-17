"""Blender background: extract rest-relative global rotations, never modify source FBX."""
import bpy, json, os
from mathutils import Matrix
base = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../assets/mixamo-life'))
conversion = Matrix(((1,0,0),(0,0,1),(0,-1,0)))
clips = {}
for name in ('Waving', 'Drinking'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(base, name+'.fbx'))
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    action = rig.animation_data.action
    start, end = action.frame_range
    fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    frames = []
    for frame in range(int(start), int(end)+1):
        bpy.context.scene.frame_set(frame)
        rotations = {}
        for bone in rig.pose.bones:
            rest = (rig.matrix_world @ bone.bone.matrix_local).to_quaternion().to_matrix()
            pose = (rig.matrix_world @ bone.matrix).to_quaternion().to_matrix()
            q = (conversion @ pose @ rest.inverted() @ conversion.inverted()).to_quaternion()
            rotations[bone.name.split(':')[-1]] = [q.x,q.y,q.z,q.w]
        frames.append(rotations)
    clips[name] = {'fps':fps, 'length':(end-start)/fps, 'frames':frames}
    print(name, 'frames', len(frames), 'fps', fps)
with open('/tmp/cuiyu_mixamo_life.json','w') as f: json.dump(clips,f)

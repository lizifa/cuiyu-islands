shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 // South-facing facade: the interior side is transparent; exterior is reflective.
 float exterior=step(world_position.z,CAMERA_POSITION_WORLD.z);
 ALBEDO=mix(vec3(.58,.77,.78),vec3(.16,.34,.38),exterior);
 ALPHA=mix(.10,1.0,exterior);
}

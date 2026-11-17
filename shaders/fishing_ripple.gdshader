shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
#include "res://shaders/ocean_surface.gdshaderinc"
uniform float impact_age = 0.0;
uniform float ripple_strength = 1.0;
varying vec3 water_point;
void vertex(){
 water_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float edge=1.0-smoothstep(55.0,70.0,max(abs(water_point.x),abs(water_point.z)));
 VERTEX.y+=ocean_wave(water_point.xz,TIME).x*edge;
}
void fragment(){
 float radius=length((UV-.5)*4.0);
 float age=max(impact_age,0.0);
 float front=.10+age*.9;
 float first=(1.0-smoothstep(.012,.045,abs(radius-front)))*(1.0-smoothstep(.15,1.45,age));
 float second=(1.0-smoothstep(.012,.035,abs(radius-max(.06,front-.22))))*smoothstep(.15,.35,age)*(1.0-smoothstep(.4,1.6,age));
 float float_ring=(1.0-smoothstep(.008,.025,abs(radius-(.12+sin(age*2.0)*.012))))*.15;
 ALBEDO=vec3(.74,.89,.87);
 ALPHA=clamp(first*.55+second*.3+float_ring,0.0,.65)*ripple_strength;
}

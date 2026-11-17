shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
#include "res://shaders/ocean_surface.gdshaderinc"
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float edge=1.0-smoothstep(55.0,70.0,max(abs(world.x),abs(world.z)));
 VERTEX.y+=ocean_wave(world.xz,TIME).x*edge;
}
void fragment(){
 vec2 p=UV*2.0-1.0;
 float width=mix(.06,.88,pow(UV.y,.6));
 float edge=(1.0-smoothstep(width*.3,width,abs(p.x)))*smoothstep(0.0,.18,UV.y)*(1.0-smoothstep(.72,1.0,UV.y));
 float grain=ocean_noise(UV*vec2(3.0,10.0));
 ALBEDO=vec3(.77,.94,.93);
 ALPHA=COLOR.a*edge*smoothstep(.25,.65,grain);
}

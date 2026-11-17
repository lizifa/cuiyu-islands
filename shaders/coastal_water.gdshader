shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 water_color : source_color=vec4(.17,.52,.59,.65);
uniform bool shore_depth_enabled=true;
uniform sampler2D shore_depth : filter_linear, repeat_disable;
uniform float dock_light_strength=0.0;
#include "res://shaders/ocean_surface.gdshaderinc"
varying vec3 world_point;
void vertex(){
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 // Fade before the far patches overlap, avoiding intersecting water planes.
 float edge=1.0-smoothstep(55.0,70.0,max(abs(world_point.x),abs(world_point.z)));
 float height=ocean_wave(world_point.xz,TIME).x*edge;
 VERTEX.y+=height;world_point.y+=height;
}
void fragment(){
 vec2 uv=(world_point.xz+vec2(64.0))/128.0;
 float depth=texture(shore_depth,clamp(uv,vec2(0.0),vec2(1.0))).r;
 if(!shore_depth_enabled||any(lessThan(uv,vec2(0.0)))||any(greaterThan(uv,vec2(1.0))))depth=1.0;
 ALBEDO=ocean_shade(world_point,CAMERA_POSITION_WORLD,water_color.rgb,depth,TIME);
 vec2 lamp=world_point.xz-vec2(-1.15,18.6);
 float lamp_pool=exp(-dot(lamp,lamp)/13.0);
 ALBEDO+=vec3(.48,.34,.15)*lamp_pool*dock_light_strength*(.8+ocean_noise(world_point.xz*.7+TIME*.04)*.2);
 ALPHA=mix(.4,1.0,smoothstep(.02,.65,depth));
}

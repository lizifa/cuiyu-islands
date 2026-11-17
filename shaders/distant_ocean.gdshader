shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 water_color : source_color=vec3(.17,.52,.59);
#include "res://shaders/ocean_surface.gdshaderinc"
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){ALBEDO=ocean_shade(world_point,CAMERA_POSITION_WORLD,water_color,1.0,TIME);}

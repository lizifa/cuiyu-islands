// Shared world-space spectrum and light response keep near and far water continuous.
uniform vec3 solar_direction=vec3(0.0,1.0,0.0);
uniform vec3 sun_color : source_color=vec3(1.0,.9,.7);
uniform vec3 horizon_color : source_color=vec3(.58,.76,.82);
uniform float light_level=1.0;
float ocean_hash(vec2 p){
 vec3 h=fract(vec3(p.xyx)*.1031);
 h+=dot(h,h.yzx+33.33);
 return fract((h.x+h.y)*h.z);
}
float ocean_noise(vec2 p){
 vec2 cell=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(ocean_hash(cell),ocean_hash(cell+vec2(1,0)),f.x),mix(ocean_hash(cell+vec2(0,1)),ocean_hash(cell+vec2(1,1)),f.x),f.y);
}
vec3 ocean_wave(vec2 p,float time){
 vec2 d0=vec2(.94,.34);vec2 d1=vec2(-.45,.89);vec2 d2=vec2(.25,-.97);
 float a=dot(p,d0)*.35-time*.65;
 float b=dot(p,d1)*.66+time*.83;
 float c=dot(p,d2)*1.49-time*1.1;
 float height=sin(a)*.065+sin(b)*.032+sin(c)*.014;
 vec2 slope=cos(a)*.02275*d0+cos(b)*.02112*d1+cos(c)*.02086*d2;
 return vec3(height,slope);
}
vec3 ocean_normal(vec2 p,float time,float detail){
 vec3 wave=ocean_wave(p,time);
 float ripple=dot(p,vec2(.88,-.47))*2.1+sin(p.x*.16+p.y*.11-time*.2)*.55+time*1.25;
 vec2 micro=vec2(.88,-.47)*cos(ripple)*.024*detail;
 return normalize(vec3(-wave.y-micro.x,1.0,-wave.z-micro.y));
}
vec3 ocean_shade(vec3 at,vec3 eye,vec3 base,float depth,float time){
 float distance_to_view=distance(at.xz,eye.xz);
 float detail=1.0-smoothstep(35.0,130.0,distance_to_view);
 vec3 n=ocean_normal(at.xz,time,detail);
 vec3 view_direction=normalize(eye-at);
 float fresnel=pow(1.0-clamp(dot(n,view_direction),0.0,1.0),4.0);
 float grain=ocean_noise(at.xz*.63+vec2(time*.045,-time*.065));
 vec3 body=mix(base*.92,vec3(.018,.125,.20),smoothstep(.06,.85,depth)*.46);
 body*=.97+(grain-.5)*.065*detail;
 vec3 sky=horizon_color*(.18+.82*light_level);
 vec3 color=mix(body*light_level,sky,.08+fresnel*.58);
 float glitter=pow(max(dot(view_direction,reflect(-normalize(solar_direction),n)),0.0),64.0);
 glitter*=max(solar_direction.y,0.0)*(.55+grain*.45)*(.12+detail*.88);
 color+=sun_color*glitter*.48;
 // Foam belongs only to shallow coastal pockets, never as all-over contour stripes.
 float shore=(1.0-smoothstep(.025,.15,depth))*smoothstep(.005,.025,depth);
 color=mix(color,vec3(.69,.85,.83)*light_level,shore*smoothstep(.64,.86,grain)*.3*detail);
 return mix(color,sky,smoothstep(80.0,850.0,distance_to_view));
}

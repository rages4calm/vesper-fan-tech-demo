shader_type spatial;
render_mode cull_disabled;

// Existing licensed PBR maps remain the surface. Weathering is anchored to the
// world, with broad continuous noise: no animated grain, decals or coplanar faces.
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 patina : source_color = vec3(.27,.25,.17);
uniform float variation = .16;
uniform float damp_strength = .3;
uniform float ground_height = 2.0;
uniform float relief = .42;
uniform float seed = 0.0;
varying vec3 world_position;
varying vec3 world_normal;

float hash(vec3 p) {
    p=fract(p*.1031);
    p+=dot(p,p.yzx+33.33);
    return fract((p.x+p.y)*p.z);
}
float weather_noise(vec3 p) {
    vec3 i=floor(p), f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
               mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    vec3 p=world_position+vec3(seed,0.0,seed*.37);
    float broad=weather_noise(p*.36);
    float worn=weather_noise(p*vec3(1.15,.18,1.15));
    float uneven=(broad*.65+worn*.35);
    float footing=1.0-smoothstep(ground_height+.12,ground_height+.85+uneven*.85,world_position.y);
    float vertical=1.0-abs(world_normal.y);
    vec3 base=texture(base_map,UV).rgb*tint.rgb;
    base*=1.0-variation*(1.0-uneven);
    base=mix(base,base*patina,footing*damp_strength*vertical);
    ALBEDO=base;
    NORMAL_MAP=texture(normal_map,UV).rgb;
    NORMAL_MAP_DEPTH=relief;
    ROUGHNESS=clamp(texture(roughness_map,UV).g*.85+.15,.65,1.0);
    SPECULAR=.18;
}

// Assets: UnionBytes / Achim Menzel and contributors, Godot 4 port by Hayden Connor.
// MIT notices: docs/licenses/UNIONBYTES-WATER.txt. Vesper-specific shader integration.
shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform vec3 deep_color : source_color = vec3(0.055,0.16,0.17);
uniform float wind_strength = 1.0;
uniform sampler2D normal_a : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_b : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D foam_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest;
uniform sampler2D reflection_texture : filter_linear;
uniform mat4 reflection_matrix;
uniform float reflection_strength = 0.55;
varying vec3 world_pos;
void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    VERTEX.y += (sin(dot(p.xz,vec2(.12,.18))+TIME*.48)*.065
                +sin(dot(p.xz,vec2(-.21,.08))-TIME*.37)*.035)*wind_strength;
    world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    vec2 p = world_pos.xz;
    vec2 flow = vec2(TIME*.0045,TIME*.0028);
    vec3 a = texture(normal_a,p*.044-flow).xyz*2.0-1.0;
    vec3 b = texture(normal_b,p*.11+flow*.65+a.xy*.025).xyz*2.0-1.0;
    float distance_fade = 1.0-smoothstep(45.0,180.0,length(VERTEX));
    vec2 slope = a.xy*.28+b.xy*mix(.045,.14,distance_fade);
    slope += vec2(.012*cos(dot(p,vec2(.12,.18))+TIME*.48),.009*cos(dot(p,vec2(-.21,.08))-TIME*.37));
    NORMAL = normalize((VIEW_MATRIX*vec4(normalize(vec3(-slope.x,1.0,-slope.y)),0.0)).xyz);
    // Reverse-Z reconstruction supports orthographic and perspective cameras.
    float raw_depth = texture(scene_depth,SCREEN_UV).r;
    vec4 behind = INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,raw_depth,1.0);
    float gap = max(0.0,-behind.z/behind.w+VERTEX.z);
    float contact = (1.0-smoothstep(.06,.9,gap))*step(.001,raw_depth);
    float bubbles = texture(foam_map,p*.8+flow*1.7).r;
    float foam = contact*smoothstep(.32,.72,bubbles)*.18;
    vec4 projected=reflection_matrix*vec4(world_pos,1.0);
    vec2 uv=projected.xy/projected.w*.5+.5;
    uv.y=1.0-uv.y;
    uv+=slope*.025;
    vec3 reflected=texture(reflection_texture,clamp(uv,vec2(.002),vec2(.998))).rgb;
    float fresnel=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),5.0);
    float reflect_mix=reflection_strength*mix(.30,1.0,fresnel);
    vec3 body=mix(deep_color,vec3(.10,.22,.20),exp(-gap*.7)*.22);
    ALBEDO=mix(body*(1.0-reflect_mix),vec3(.48,.55,.48),foam);
    EMISSION=reflected*reflect_mix*.50*(1.0-foam);
    METALLIC=0.0;
    ROUGHNESS=mix(.25,.48,foam);
    SPECULAR=.45;
    ALPHA=1.0;
}

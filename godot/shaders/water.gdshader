shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.025,0.13,0.16);
uniform float wind_strength = 1.0;
uniform sampler2D ripples : repeat_enable, filter_linear_mipmap;
uniform sampler2D reflection_texture : filter_linear;
uniform mat4 reflection_matrix;
uniform float reflection_strength = 0.55;
varying vec3 world_pos;

float swell(vec2 p, float t) {
    return sin(p.x * 0.30 + t * 0.57) * 0.035 + sin(p.y * 0.48 - t * 0.71) * 0.025 + sin(dot(p,vec2(0.83,0.36)) + t) * 0.014;
}
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    VERTEX.y += swell(world_pos.xz, TIME) * wind_strength;
}
void fragment() {
    vec2 p = world_pos.xz;
    float t = TIME;
    vec3 n1 = texture(ripples,p*.065+vec2(t*.008,t*.004)).rgb*2.0-1.0;
    vec3 n2 = texture(ripples,p*.13+vec2(-t*.006,t*.003)).rgb*2.0-1.0;
    float dx = n1.x*.17+n2.x*.07;
    float dz = n1.y*.17+n2.y*.07;
    NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-dx,1.0,-dz)),0.0)).xyz);
    vec4 projected = reflection_matrix * vec4(world_pos,1.0);
    vec2 uv = projected.xy / projected.w * 0.5 + 0.5;
    uv.y = 1.0-uv.y;
    uv += vec2(dx,dz)*.02;
    vec3 reflected = texture(reflection_texture,clamp(uv,vec2(.002),vec2(.998))).rgb;
    float fresnel = pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),4.0);
    float mix_amount = reflection_strength * (.55+fresnel*.45);
    ALBEDO = deep_color*(1.0-mix_amount);
    EMISSION = reflected*mix_amount*.32;
    METALLIC = .22;
    ROUGHNESS = .20;
    SPECULAR = .8;
}

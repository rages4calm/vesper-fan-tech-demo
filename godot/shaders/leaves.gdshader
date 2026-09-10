shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color = vec4(.23,.34,.10,1.0);
void vertex() {
    vec3 world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    float height = smoothstep(2.0,9.0,VERTEX.y);
    VERTEX.x += sin(TIME*.9+world.x*.14+world.z*.11)*height*.12;
    VERTEX.z += sin(TIME*1.1+world.z*.20)*height*.065;
}
void fragment() {
    ALBEDO = leaf_color.rgb;
    ROUGHNESS = .88;
    BACKLIGHT = leaf_color.rgb*.14;
}

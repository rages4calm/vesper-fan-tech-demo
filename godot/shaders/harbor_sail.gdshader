shader_type spatial;
render_mode cull_disabled;
uniform sampler2D weave : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 cloth_color : source_color = vec4(.86,.82,.70,1.0);
uniform float flutter = .075;
void vertex() {
    float pinned = sin(UV.x*3.14159)*sin(UV.y*3.14159);
    VERTEX.x += pinned * flutter * (sin(TIME*1.3+VERTEX.y*1.2)+.3*sin(TIME*2.7+VERTEX.z));
}
void fragment() {
    vec3 fiber = texture(weave,UV*vec2(5.0,7.0)).rgb;
    float shade = mix(.82,1.0,dot(fiber,vec3(.3333)));
    ALBEDO=cloth_color.rgb*shade;
    ROUGHNESS=.94;
    SPECULAR=.15;
    BACKLIGHT=cloth_color.rgb*.10;
}

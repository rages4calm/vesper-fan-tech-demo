shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grain : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grain_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 timber_color : source_color = vec4(.72,.53,.33,1.0);
uniform float roughness = .84;
void fragment() {
    vec3 sample_color=texture(grain,UV).rgb;
    float grain_value=dot(sample_color,vec3(.2126,.7152,.0722));
    ALBEDO=timber_color.rgb*clamp(grain_value*2.4,.13,1.45);
    NORMAL_MAP=texture(grain_normal,UV).rgb;
    NORMAL_MAP_DEPTH=.38;
    ROUGHNESS=roughness;
    SPECULAR=.3;
}

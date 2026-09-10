shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, shadows_disabled, cull_back;

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;

void fragment() {
    float depth = textureLod(scene_depth, SCREEN_UV, 0.0).r;
    vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
    float surface_distance = -scene.z / scene.w;
    float traveler_distance = -VERTEX.z;
    // Ignore the ranger's own layered clothing and limbs in the depth buffer.
    if (surface_distance >= traveler_distance - 1.4) discard;
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
    ALBEDO = vec3(0.88, 0.73, 0.44);
    ALPHA = 0.30 + rim * 0.58;
}

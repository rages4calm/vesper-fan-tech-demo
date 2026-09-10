shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, world_vertex_coords;
void vertex() {
    VERTEX.y=.10+sin(VERTEX.x*.30+TIME*.57)*.02+sin(VERTEX.z*.48-TIME*.71)*.02;
}
void fragment() {
    vec2 p=UV*2.0-1.0;
    float edge=1.0-smoothstep(.35,1.0,length(p));
    float foam=smoothstep(.1,.6,sin(UV.x*37.0+sin(UV.y*22.0))*sin(UV.y*31.0));
    ALBEDO=vec3(.74,.83,.79);
    ALPHA=edge*foam*COLOR.a*.40;
}

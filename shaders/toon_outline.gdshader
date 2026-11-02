shader_type spatial;
// Contorno anime (casca invertida): desenha só as faces de trás, um pouco infladas.
render_mode unshaded, cull_front, fog_disabled, depth_draw_opaque;
uniform vec4 color : source_color = vec4(0.13, 0.07, 0.05, 1.0);
uniform float width = 0.0045;
global uniform vec4 world_light;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb * mix(vec3(1.0), world_light.rgb, 0.85);
}

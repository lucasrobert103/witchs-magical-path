shader_type spatial;
// Soft slanted god rays through the canopy.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform vec4 color : source_color = vec4(1.0, 0.92, 0.7, 1.0);
uniform float energy = 0.18;
uniform float slant = 0.35;
varying float v_fade;

void vertex() {
	VERTEX.x += VERTEX.y * slant;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	float d = length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	v_fade = smoothstep(3.0, 11.0, d);
}

void fragment() {
	vec4 t = texture(tex, UV);
	float shimmer = 0.75 + 0.25 * sin(TIME * 0.7 + UV.x * 6.0);
	ALBEDO = color.rgb * t.a * energy * shimmer * v_fade;
}

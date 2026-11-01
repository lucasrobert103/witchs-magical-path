shader_type spatial;
// Additive light sprites: magic, fireflies, runes, glowing pools.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 1.0;
uniform float pulse = 0.0;
uniform float pulse_speed = 2.0;
uniform bool face_camera = true;
uniform float near_fade = 0.0;

varying float v_fade;

void vertex() {
	if (face_camera) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	}
	float d = length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	v_fade = near_fade > 0.0 ? smoothstep(near_fade * 0.4, near_fade, d) : 1.0;
}

void fragment() {
	vec4 t = texture(tex, UV);
	float p = 1.0 + pulse * sin(TIME * pulse_speed);
	ALBEDO = t.rgb * color.rgb * energy * p * t.a * color.a * v_fade;
}

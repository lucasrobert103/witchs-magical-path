shader_type spatial;
// Asterion's sprite: Y-billboard, soft edges, no fog wash-out, gentle forest tint.
render_mode unshaded, cull_disabled, depth_prepass_alpha, fog_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.06, 1.05, 1.02, 1.0);
uniform vec4 haze : source_color = vec4(0.56, 0.66, 0.6, 1.0);
uniform float haze_amount = 0.06;
uniform vec4 rim : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform float rim_amount = 0.1;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.45, 0.4, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(tex, UV);
	vec3 col = c.rgb * tint.rgb;
	// Thin warm rim where the alpha falls off (light from the canopy).
	float edge = 1.0 - smoothstep(0.35, 0.95, c.a);
	col += rim.rgb * edge * rim_amount;
	col = mix(col, haze.rgb, haze_amount);
	ALBEDO = mix(col, flash_color.rgb, flash * 0.65);
	ALPHA = c.a * tint.a;
}

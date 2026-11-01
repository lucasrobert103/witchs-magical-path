shader_type spatial;
// Flowing river: UV.x runs downstream, UV.y across the bed.
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 deep : source_color = vec4(0.07, 0.24, 0.3, 1.0);
uniform vec4 shallow : source_color = vec4(0.3, 0.58, 0.6, 1.0);
uniform vec4 sky : source_color = vec4(0.95, 0.82, 0.62, 1.0);
uniform float speed = 0.12;
global uniform vec4 world_light;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float n1 = texture(noise_tex, vec2(UV.x * 0.6 - TIME * speed, UV.y * 0.8)).r;
	float n2 = texture(noise_tex, vec2(UV.x * 1.7 - TIME * speed * 1.6, UV.y * 2.3 + 0.4)).r;
	vec3 col = mix(deep.rgb, shallow.rgb, smoothstep(0.2, 1.0, across) * 0.8);
	float streak = smoothstep(0.62, 0.8, n1 * 0.6 + n2 * 0.6);
	col = mix(col, sky.rgb, streak * 0.35 + (1.0 - across) * 0.08);
	float foam = smoothstep(0.82, 0.98, across) * (0.5 + 0.5 * n2);
	col = mix(col, vec3(0.9, 0.95, 0.95), foam * 0.45);
	ALBEDO = col * mix(vec3(1.0), world_light.rgb, 0.85);
	ALPHA = (1.0 - smoothstep(0.93, 1.0, across)) * 0.92;
}

shader_type spatial;
// Glowing spring water with ripples and drifting caustics.
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 deep : source_color = vec4(0.03, 0.18, 0.22, 1.0);
uniform vec4 glow : source_color = vec4(0.45, 0.95, 1.0, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float energy = 1.0;
global uniform vec4 world_light;

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float n = texture(noise_tex, UV * 1.6 + vec2(TIME * 0.03, TIME * 0.02)).r;
	float n2 = texture(noise_tex, UV * 2.7 - vec2(TIME * 0.025, 0.0)).r;
	float caustic = smoothstep(0.55, 0.75, n * 0.6 + n2 * 0.6);
	float ripple = 0.5 + 0.5 * sin(r * 26.0 - TIME * 2.2 + n * 3.0);
	float center = 1.0 - smoothstep(0.0, 0.9, r);
	vec3 col = mix(deep.rgb, glow.rgb, center * 0.55 * energy + caustic * 0.35 * energy);
	col += glow.rgb * ripple * 0.08 * energy * (1.0 - r);
	col += vec3(1.0) * smoothstep(0.86, 0.93, r) * (1.0 - smoothstep(0.93, 1.0, r)) * 0.25;
	ALBEDO = col * mix(vec3(1.0), world_light.rgb, 0.5);
	ALPHA = (1.0 - smoothstep(0.92, 1.0, r)) * 0.92;
}

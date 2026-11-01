shader_type spatial;
// Shimmering magical seal inside the sanctuary arch.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 moon : source_color = vec4(0.45, 0.8, 1.0, 1.0);
uniform vec4 flame : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform float strength = 1.0;

void fragment() {
	vec2 uv = UV;
	float n = texture(noise_tex, uv * vec2(1.0, 1.6) + vec2(0.0, -TIME * 0.05)).r;
	float n2 = texture(noise_tex, uv * vec2(2.2, 1.2) + vec2(TIME * 0.03, TIME * 0.02)).r;
	float swirl = smoothstep(0.4, 0.8, n * 0.7 + n2 * 0.5);
	vec3 col = mix(moon.rgb, flame.rgb, smoothstep(0.3, 0.7, uv.x + (n - 0.5) * 0.4));
	vec2 q = vec2((uv.x - 0.5) / 0.5, (uv.y - 0.333) / 0.333);
	float inside = uv.y > 0.333 ? 1.0 - smoothstep(0.88, 1.0, abs(q.x)) : 1.0 - smoothstep(0.88, 1.0, length(q));
	float floor_fade = smoothstep(1.0, 0.9, uv.y);
	float edge_glow = (1.0 - inside) * 0.0 + smoothstep(0.7, 0.98, uv.y > 0.333 ? abs(q.x) : length(q)) * inside;
	ALBEDO = col * (0.12 + swirl * 0.5 + edge_glow * 0.6) * inside * floor_fade * strength;
}

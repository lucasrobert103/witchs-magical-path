shader_type spatial;
// Painted forest floor: grass, moss, leaf litter and flagstone path blended by a
// layout mask, with slowly drifting dappled sunlight.
render_mode unshaded;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D dapple_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 world_min = vec2(-50.0, -90.0);
uniform vec2 world_size = vec2(100.0, 170.0);
uniform vec4 light_tint : source_color = vec4(1.0, 0.93, 0.76, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.42, 0.52, 0.5, 1.0);
uniform vec4 pool_glow : source_color = vec4(0.35, 0.85, 0.95, 1.0);
uniform float dapple_strength = 1.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = wpos.xz;
	vec4 m = texture(mask_tex, (w - world_min) / world_size);
	float macro = texture(dapple_tex, w * 0.013).r;
	vec3 grass = texture(grass_tex, w * 0.2).rgb;
	vec3 moss = texture(moss_tex, w * 0.16 + 0.3).rgb;
	vec3 dirt = texture(dirt_tex, w * 0.22).rgb;
	vec3 path = texture(path_tex, w * 0.3).rgb;
	vec3 col = mix(moss, grass, smoothstep(0.15, 0.85, m.r + (macro - 0.5) * 0.5));
	col = mix(col, dirt, clamp(m.b + (1.0 - m.r) * 0.25 * macro, 0.0, 1.0));
	float p = smoothstep(0.42, 0.7, m.g + (macro - 0.5) * 0.35);
	col = mix(col, mix(dirt, path, 0.85), p);
	float d1 = texture(dapple_tex, w * 0.075 + vec2(TIME * 0.006, TIME * 0.003)).r;
	float d2 = texture(dapple_tex, w * 0.043 - vec2(TIME * 0.004, -TIME * 0.002)).r;
	float sun = smoothstep(0.5, 0.72, d1 * 0.55 + d2 * 0.55) * dapple_strength;
	float open = smoothstep(0.1, 0.9, m.r);
	col *= mix(shadow_tint.rgb, light_tint.rgb * 1.22, clamp(0.25 + sun * (0.25 + 0.6 * open) + open * 0.2, 0.0, 1.0));
	col *= mix(0.5, 1.0, smoothstep(0.0, 0.5, m.r));
	col += pool_glow.rgb * m.a * 0.55;
	ALBEDO = col;
}

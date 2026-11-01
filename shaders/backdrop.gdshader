shader_type spatial;
// Far painted scenery (mountains, hills): own atmospheric haze instead of scene fog.
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_mix;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 haze : source_color = vec4(0.8, 0.78, 0.75, 1.0);
uniform float haze_amount = 0.35;
global uniform vec4 world_light;

void fragment() {
	vec4 c = texture(tex, UV);
	vec3 col = mix(c.rgb, haze.rgb, haze_amount);
	ALBEDO = col * world_light.rgb;
	ALPHA = c.a;
}

shader_type spatial;
// Solid tree trunks: painted bark, soft directional light, moss and dark roots.
render_mode unshaded, cull_back;
uniform sampler2D bark : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 sun_dir = vec3(-0.45, 0.75, 0.35);
uniform vec4 moss_color : source_color = vec4(0.3, 0.4, 0.2, 1.0);
global uniform vec4 world_light;
varying vec3 wn;
varying float h;
varying float var;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	h = VERTEX.y * length(MODEL_MATRIX[1].xyz);
	var = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(bark, UV).rgb * tint.rgb * (0.85 + var * 0.3);
	float d = clamp(dot(wn, normalize(sun_dir)), 0.0, 1.0);
	c *= 0.5 + 0.75 * d;
	float moss = (1.0 - smoothstep(0.2, 2.2, h)) * smoothstep(0.35, 0.65, texture(bark, UV * 0.37 + 0.2).g * 1.6);
	c = mix(c, moss_color.rgb * (0.7 + d * 0.5), moss * 0.55);
	c *= mix(0.45, 1.0, smoothstep(0.0, 1.2, h));
	ALBEDO = c * world_light.rgb;
}

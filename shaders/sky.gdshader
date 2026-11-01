shader_type sky;
// Misty forest sky: warm light breaking through teal haze.
uniform vec4 top : source_color = vec4(0.16, 0.26, 0.25, 1.0);
uniform vec4 horizon : source_color = vec4(0.62, 0.72, 0.64, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform vec3 sun_dir = vec3(-0.3, 0.5, -0.8);

void sky() {
	float h = clamp(EYEDIR.y, -1.0, 1.0);
	vec3 col = mix(horizon.rgb, top.rgb, smoothstep(0.0, 0.7, h));
	col = mix(col, horizon.rgb * 0.7, smoothstep(0.0, -0.3, h));
	float s = max(dot(normalize(EYEDIR), normalize(sun_dir)), 0.0);
	col += sun_color.rgb * pow(s, 10.0) * 0.45;
	COLOR = col;
}

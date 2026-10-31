shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.5, 0.4, 0.3, 1.0);
uniform float fill = 0.075;

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 1.0;
	EMISSION = base_color.rgb * fill;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float band = 0.23 + 0.48 * smoothstep(-0.05, 0.035, facing) + 0.29 * smoothstep(0.64, 0.70, facing);
	float shadow = mix(0.25, 1.0, smoothstep(0.25, 0.7, ATTENUATION));
	DIFFUSE_LIGHT += LIGHT_COLOR * band * shadow / 3.14159265;
}

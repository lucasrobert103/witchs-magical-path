// Shared vertex/fragment code for painted sprites placed in the 3D world.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float sway = 0.0;
uniform float sway_speed = 1.2;
uniform bool billboard = true;
uniform float ground_shade = 0.22;
uniform vec4 ground_color : source_color = vec4(0.16, 0.2, 0.15, 1.0);
uniform float top_light = 0.0;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
varying float v_var;
global uniform vec4 world_light;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float w = 1.0 - UV.y;
	w = w * w;
	VERTEX.x += (sin(TIME * sway_speed + phase) + 0.35 * sin(TIME * sway_speed * 2.3 + phase * 1.7)) * sway * w;
	v_var = INSTANCE_CUSTOM.r;
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

vec4 painted(vec2 uv) {
	vec4 c = texture(tex, uv * uv_scale + uv_offset);
	vec3 col = c.rgb * tint.rgb;
	// Per-instance hue/brightness variation.
	col *= 0.9 + v_var * 0.2;
	// Ambient occlusion near the ground, warm light from the canopy above.
	float g = smoothstep(0.0, ground_shade, 1.0 - uv.y);
	col = mix(col * ground_color.rgb * 2.2, col, g);
	col += vec3(1.0, 0.85, 0.55) * top_light * (1.0 - uv.y) * (1.0 - uv.y) * c.a;
	return vec4(col * world_light.rgb, c.a * tint.a);
}

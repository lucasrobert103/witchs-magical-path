shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.33, 0.57, 0.22, 1.0);
uniform vec4 tip_color : source_color = vec4(0.65, 0.76, 0.34, 1.0);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.18;
varying float blade_height;

void vertex() {
    vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    blade_height = UV.y;
    float flutter = sin(TIME * 1.8 + world_position.x * 0.19 + world_position.z * 0.12);
    float gust = sin(TIME * 0.65 + world_position.x * 0.065 - world_position.z * 0.045);
    VERTEX.x += (flutter * 0.65 + gust * 0.35) * wind_strength * UV.y * UV.y;
    VERTEX.z += cos(TIME * 1.2 + world_position.x * 0.11) * wind_strength * UV.y * UV.y * 0.35;
}

void fragment() {
    ALBEDO = mix(base_color.rgb, tip_color.rgb, blade_height * blade_height * 0.8);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    EMISSION = ALBEDO * 0.045;
}

void light() {
    float incidence = abs(dot(normalize(NORMAL), normalize(LIGHT)));
    float light_band = 0.43 + smoothstep(0.16, 0.25, incidence) * 0.50;
    DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * light_band / PI;
}

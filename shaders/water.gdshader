shader_type spatial;
render_mode unshaded, cull_disabled;

// Shallow opaque water keeps mobile rendering inexpensive and predictable.
uniform vec4 water_color : source_color = vec4(0.10, 0.51, 0.58, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.33, 0.77, 0.70, 1.0);
uniform vec4 foam_color : source_color = vec4(0.83, 0.97, 0.86, 1.0);
uniform float wave_strength : hint_range(0.0, 0.2) = 0.055;
uniform float shore_width : hint_range(0.01, 0.3) = 0.12;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += (sin(world_position.x * 0.62 + TIME * 0.85) + cos(world_position.z * 0.81 - TIME * 0.65)) * wave_strength;
}

void fragment() {
    vec2 p = world_position.xz;
    float ripple_a = sin(p.x * 1.65 + p.y * 1.19 + TIME * 0.7);
    float ripple_b = sin(p.x * 1.14 - p.y * 1.85 - TIME * 0.52);
    float wave = ripple_a * ripple_b;
    float radial = length(UV * 2.0 - 1.0);
    float shallows = smoothstep(0.55, 1.0, radial);
    vec3 color = mix(water_color.rgb, shallow_color.rgb, shallows * 0.8 + (wave * 0.5 + 0.5) * 0.15);
    float glint = smoothstep(0.89, 0.97, wave) * 0.19;
    float edge = smoothstep(1.0 - shore_width, 1.0 - shore_width * 0.1, radial);
    float shore_pattern = sin(radial * 130.0 - TIME * 1.3 + ripple_a * 0.35);
    float foam = edge * smoothstep(0.2, 0.75, shore_pattern) * 0.52;
    ALBEDO = mix(color, foam_color.rgb, clamp(glint + foam, 0.0, 0.72));
}

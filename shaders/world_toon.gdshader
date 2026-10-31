shader_type spatial;
render_mode diffuse_burley, specular_disabled;

// Warm, quiet light bands. Vertex colors are authored as display-space colors.
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float ambient_lift : hint_range(0.0, 0.2) = 0.035;
uniform float rim_strength : hint_range(0.0, 0.3) = 0.055;
uniform vec3 shadow_tint : source_color = vec3(0.68, 0.78, 0.81);

varying vec3 surface_color;
varying vec3 world_position;

float pigment_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float pigment(vec2 p) {
    vec2 cell = floor(p);
    vec2 blend = fract(p);
    blend = blend * blend * (3.0 - 2.0 * blend);
    return mix(mix(pigment_hash(cell), pigment_hash(cell + vec2(1.0, 0.0)), blend.x),
               mix(pigment_hash(cell + vec2(0.0, 1.0)), pigment_hash(cell + vec2(1.0)), blend.x), blend.y);
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    surface_color = base_color.rgb;
    if (use_vertex_color) {
        surface_color *= COLOR.rgb;
    }
    // Subtle broad pigment patches break up the plastic appearance of flat colors.
    float brush = pigment(world_position.xz * 0.75 + world_position.y * 0.23);
    surface_color *= mix(0.94, 1.035, brush);
    ALBEDO = surface_color;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
    EMISSION = surface_color * ambient_lift + surface_color * edge * rim_strength;
}

void light() {
    float ndotl = dot(normalize(NORMAL), normalize(LIGHT));
    float low = smoothstep(0.10, 0.17, ndotl);
    float high = smoothstep(0.66, 0.73, ndotl);
    float tone = 0.25 + low * 0.51 + high * 0.13;
    vec3 tint = mix(shadow_tint, vec3(1.0), low);
    DIFFUSE_LIGHT += tint * LIGHT_COLOR * ATTENUATION * tone / PI;
}

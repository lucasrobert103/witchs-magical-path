shader_type spatial;
// Painted sprites with soft anti-aliased edges (ruins, runestones, actors).
render_mode unshaded, cull_disabled, depth_prepass_alpha;
#include "res://shaders/billboard_common.gdshaderinc"
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

void fragment() {
	vec4 c = painted(UV);
	ALBEDO = mix(c.rgb, flash_color.rgb, flash);
	ALPHA = c.a;
}

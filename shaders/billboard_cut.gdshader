shader_type spatial;
// Opaque painted sprites (trees, grass, props): alpha scissor, order independent.
render_mode unshaded, cull_disabled, depth_draw_opaque;
#include "res://shaders/billboard_common.gdshaderinc"
uniform float alpha_cut = 0.5;

void fragment() {
	vec4 c = painted(UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
}

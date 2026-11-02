// Asterion 3D: cel shading (2 tons + reflexo suave + luz de recorte), no estilo anime da ficha.
// Sem iluminação da cena (unshaded): a luz é fixa no mundo e o tom geral vem de world_light,
// igual aos sprites pintados do cenário — assim ela combina com o dia e com a noite.
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = false;
uniform vec2 uv_offset = vec2(0.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec3 light_dir = vec3(-0.45, 0.8, 0.55);     // direção (mundo) de onde vem a luz
uniform vec4 shade_tint : source_color = vec4(0.62, 0.55, 0.66, 1.0);
uniform float shade_threshold = 0.47;
uniform float shade_soft = 0.035;
uniform float light_boost = 1.08;
uniform vec4 rim_color : source_color = vec4(1.0, 0.86, 0.62, 1.0);
uniform float rim_amount = 0.32;
uniform float spec_amount = 0.0;                      // brilho do cabelo / metal
uniform float spec_size = 0.12;
uniform vec4 haze : source_color = vec4(0.56, 0.66, 0.6, 1.0);
uniform float haze_amount = 0.05;
uniform sampler2D detail : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail_amount = 0.0;          // trama do tecido, granulado do couro, fios do cabelo
uniform vec2 detail_scale = vec2(1.0);
uniform float ao_amount = 1.0;              // oclusão gravada nos vértices (dobras, sob a capa)
uniform float lining = 0.68;                // lado de dentro de tecidos (forro mais escuro)
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.45, 0.4, 1.0);
global uniform vec4 world_light;

void fragment() {
	vec4 c = albedo;
	if (use_tex) {
		c *= texture(tex, UV * uv_scale + uv_offset);
	}
	float d = texture(detail, UV * detail_scale).r;
	c.rgb *= mix(1.0, d * 2.0, detail_amount);
	vec3 vn = FRONT_FACING ? NORMAL : -NORMAL;
	if (!FRONT_FACING) {
		c.rgb *= lining;
	}
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(vn, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 l = normalize(light_dir);
	float ndl = dot(n, l) * 0.5 + 0.5;
	float lit = smoothstep(shade_threshold - shade_soft, shade_threshold + shade_soft, ndl);
	vec3 col = mix(c.rgb * shade_tint.rgb, c.rgb * light_boost, lit);
	// reflexo em faixa (cabelo, couro, bronze)
	vec3 h = normalize(l + v);
	float sp = smoothstep(1.0 - spec_size, 1.0 - spec_size * 0.6, max(dot(n, h), 0.0));
	col += c.rgb * sp * spec_amount * lit;
	// luz de recorte (contorno quente vindo do fundo da floresta)
	float ao = mix(1.0, COLOR.r, ao_amount);
	col *= ao;
	float rim = 1.0 - clamp(dot(vn, VIEW), 0.0, 1.0);
	rim = smoothstep(0.62, 0.78, rim) * (0.35 + 0.65 * lit);
	col += rim_color.rgb * rim * rim_amount * (0.4 + c.rgb) * ao;
	col = mix(col, haze.rgb, haze_amount);
	col *= mix(vec3(1.0), world_light.rgb, 0.85);
	ALBEDO = mix(col, flash_color.rgb, flash * 0.65);
}

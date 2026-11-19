shader_type spatial;
// 小镇地面：每格按"地面种类"选贴图（重度污染 / 轻度污染 / 清理过 / 草地 / 泥土河道），
// 贴图按世界坐标平铺，所以相邻格子之间看不出接缝。
// 种类放在每格的 INSTANCE_CUSTOM.r（0～6：5 柏油路、6 斑马线），叠加色（锁住变暗、有水偏蓝、通电偏蓝紫）放在 COLOR。

uniform sampler2D tex_polluted : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_cleared : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_soil : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_road : source_color, filter_linear_mipmap, repeat_enable;
uniform float stripe_meters = 1.0; // 斑马线一道白一道黑各多宽
uniform float tile_meters = 6.0;
uniform float light_pollution_mix = 0.5;
uniform float soil_desaturate = 0.65; // 泥土贴图偏红，去掉一部分颜色变成灰褐

varying vec3 world_pos;
varying float kind;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	kind = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec2 uv = world_pos.xz / tile_meters;
	vec3 polluted = texture(tex_polluted, uv).rgb;
	vec3 cleared = texture(tex_cleared, uv).rgb;
	vec3 base = polluted;
	if (kind > 4.5) {
		base = texture(tex_road, uv).rgb;
		if (kind > 5.5 && fract(world_pos.x / (stripe_meters * 2.0)) < 0.5) {
			base = mix(base, vec3(0.85), 0.8);
		}
	} else if (kind > 3.5) {
		base = texture(tex_soil, uv).rgb;
		base = mix(base, vec3(dot(base, vec3(0.333))), soil_desaturate);
	} else if (kind > 2.5) {
		base = texture(tex_grass, uv).rgb;
	} else if (kind > 1.5) {
		base = cleared;
	} else if (kind > 0.5) {
		base = mix(polluted, cleared, light_pollution_mix);
	}
	ALBEDO = base * COLOR.rgb;
	ROUGHNESS = 0.95;
}

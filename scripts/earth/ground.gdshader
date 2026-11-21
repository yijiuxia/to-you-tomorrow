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
uniform sampler2D tex_moss : source_color, filter_linear_mipmap, repeat_enable;
uniform float moss_scale;
uniform vec3 moss_tint : source_color;
varying float moss_cover;
varying float kind;
uniform sampler2D road_growth : filter_linear_mipmap, repeat_disable;
uniform vec2 map_meters;
varying float road_pollution;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float moss_noise(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	kind = INSTANCE_CUSTOM.r;
	moss_cover = INSTANCE_CUSTOM.g;
	road_pollution = INSTANCE_CUSTOM.b;
}

void fragment() {
	vec2 uv = world_pos.xz / tile_meters;
	vec3 polluted = texture(tex_polluted, uv).rgb;
	vec3 cleared = texture(tex_cleared, uv).rgb;
	vec3 base = polluted;
	if (kind > 6.5) {
        vec3 concrete = texture(tex_cleared, uv).rgb;
        base = vec3(dot(concrete,vec3(0.333)))*vec3(0.93,0.95,1.0);
    } else if (kind > 4.5) {
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
    float coverage = moss_cover * texture(road_growth,world_pos.xz/map_meters).r;
    if (road_pollution > 0.0 && kind > 4.5 && kind < 6.5) {
        coverage=texture(road_growth,world_pos.xz/map_meters).r*road_pollution;
    }
    if (coverage > 0.001) {
        // 世界坐标连续铺满，不把噪声当透明洞；噪声只改变苔层颜色和微表面。
        vec2 moss_uv = (vec2(2.04,0.04)+fract(world_pos.xz/moss_scale)*0.92)/vec2(3.0,2.0);
        vec3 moss = texture(tex_moss,moss_uv).rgb;
        float broad = moss_noise(world_pos.xz*0.22);
        float fine = moss_noise(world_pos.xz*19.0);
        vec3 moss_base = mix(moss_tint*0.55,moss_tint*1.35,broad)*(0.55+dot(moss,vec3(0.333)))*mix(0.78,1.12,fine);
        base=mix(base,moss_base,coverage);
        NORMAL_MAP=normalize(vec3((moss_noise(world_pos.xz*19.0+vec2(0.05,0))-fine)*2.0,(moss_noise(world_pos.xz*19.0+vec2(0,0.05))-fine)*2.0,1.0))*0.5+0.5;
    }
	ALBEDO = base * COLOR.rgb;
	ROUGHNESS = 0.95;
}

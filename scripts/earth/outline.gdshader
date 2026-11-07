// 游戏滤镜的描边：比较相邻像素的深度，差得多的地方画黑边。
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform float threshold = 0.4;
uniform float thickness = 1.5;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_projection) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -view.z / view.w;
}

void fragment() {
	vec2 step_size = thickness / VIEWPORT_SIZE;
	float center = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float largest = 0.0;
	largest = max(largest, abs(center - linear_depth(SCREEN_UV + vec2(step_size.x, 0.0), INV_PROJECTION_MATRIX)));
	largest = max(largest, abs(center - linear_depth(SCREEN_UV - vec2(step_size.x, 0.0), INV_PROJECTION_MATRIX)));
	largest = max(largest, abs(center - linear_depth(SCREEN_UV + vec2(0.0, step_size.y), INV_PROJECTION_MATRIX)));
	largest = max(largest, abs(center - linear_depth(SCREEN_UV - vec2(0.0, step_size.y), INV_PROJECTION_MATRIX)));
	// 越远的物体深度差天然越大，按距离放宽，不然远处地面全是黑线
	float edge = step(threshold * (1.0 + center * 0.3), largest);
	ALBEDO = vec3(0.05);
	ALPHA = edge * 0.85;
}

shader_type canvas_item;
uniform float radius = 0.42;
void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (UV - vec2(0.5)) * vec2(res.x / res.y, 1.0);
	float d = length(p);
	float a = smoothstep(radius, radius + 0.004, d);
	// تظليل حواف العدسة
	float vig = smoothstep(radius * 0.7, radius, d) * 0.45;
	COLOR = vec4(0.0, 0.0, 0.0, max(a, vig));
}

shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color = vec4(0.1, 1.0, 0.35, 1.0);
void fragment() {
	// أسطوانة شفافة تتلاشى نحو الأعلى + حلقة سفلية
	float h = UV.y;
	float a = (1.0 - h);
	a = a * a * 0.32;
	float scan = 0.5 + 0.5 * sin((h * 14.0 - TIME * 2.5) * 3.14159);
	ALBEDO = color.rgb * (0.7 + 0.5 * scan);
	ALPHA = a;
}

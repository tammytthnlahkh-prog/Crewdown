class_name UIK
## أدوات واجهة صغيرة.

static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 14, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func button(text: String, size: Vector2 = Vector2(220, 56), fs: int = 26, accent: Color = Color(0.2, 0.55, 0.95)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", box(Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.92), accent, 2))
	b.add_theme_stylebox_override("hover", box(Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, 0.95), accent.lightened(0.3), 2))
	b.add_theme_stylebox_override("pressed", box(Color(accent.r * 0.7, accent.g * 0.7, accent.b * 0.7, 1.0), Color(1, 1, 1), 2))
	b.add_theme_stylebox_override("disabled", box(Color(0.2, 0.2, 0.22, 0.8), Color(0.35, 0.35, 0.4), 2))
	return b


static func label(text: String, fs: int = 24, color: Color = Color(1, 1, 1), align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(2, fs / 9))
	l.horizontal_alignment = align
	l.text_direction = Control.TEXT_DIRECTION_AUTO
	return l


static func slider(minv: float, maxv: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(300, 36)
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grab := box(Color(0.25, 0.65, 1.0), Color(1, 1, 1), 2, 14, 0)
	s.add_theme_stylebox_override("slider", box(Color(1, 1, 1, 0.15), Color(0, 0, 0, 0), 0, 6, 4))
	s.add_theme_stylebox_override("grabber_area", box(Color(0.25, 0.65, 1.0, 0.7), Color(0, 0, 0, 0), 0, 6, 4))
	s.add_theme_stylebox_override("grabber_area_highlight", box(Color(0.35, 0.75, 1.0, 0.8), Color(0, 0, 0, 0), 0, 6, 4))
	var img := Image.create(34, 34, false, Image.FORMAT_RGBA8)
	for y in 34:
		for x in 34:
			var d := Vector2(x - 16.5, y - 16.5).length()
			if d < 15.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1) if d > 12.0 else Color(0.25, 0.65, 1.0, 1.0))
	var tex := ImageTexture.create_from_image(img)
	s.add_theme_icon_override("grabber", tex)
	s.add_theme_icon_override("grabber_highlight", tex)
	s.add_theme_icon_override("grabber_disabled", tex)
	return s


static func format_time(t: float) -> String:
	var s := maxi(0, int(ceil(t)))
	return "%d:%02d" % [s / 60, s % 60]

class_name SettingsPanel
extends PanelContainer
## لوحة الإعدادات: حساسية الكاميرا (عادي/تصويب/سكوب)، جيروسكوب، FOV، الصوت، وأزرار اللمس.

signal closed
signal edit_layout

var _name_edit: LineEdit


func _init() -> void:
	add_theme_stylebox_override("panel", UIK.box(Color(0.05, 0.07, 0.1, 0.96), Color(0.25, 0.55, 0.95), 2, 18, 16))


func build(show_name: bool) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UIK.label("الإعدادات", 34, Color(0.45, 0.8, 1.0)))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 340)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(g)
	if show_name:
		g.add_child(UIK.label("اسمك", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT))
		_name_edit = LineEdit.new()
		_name_edit.text = Settings.player_name
		_name_edit.max_length = 14
		_name_edit.custom_minimum_size = Vector2(300, 42)
		_name_edit.add_theme_font_size_override("font_size", 24)
		_name_edit.text_changed.connect(func(t: String) -> void:
			Settings.player_name = t.strip_edges())
		g.add_child(_name_edit)
	_row(g, "حساسية الكاميرا", 0.05, 0.8, 0.01, Settings.look_sens, func(x: float) -> void: Settings.look_sens = x)
	_row(g, "حساسية التصويب (ADS)", 0.1, 1.2, 0.01, Settings.ads_mult, func(x: float) -> void: Settings.ads_mult = x)
	_row(g, "حساسية السكوب (AWM)", 0.1, 1.2, 0.01, Settings.scope_mult, func(x: float) -> void: Settings.scope_mult = x)
	_row(g, "زاوية الرؤية FOV", 55.0, 85.0, 1.0, Settings.fov, func(x: float) -> void: Settings.fov = x)
	_row(g, "مستوى الصوت", 0.0, 1.0, 0.05, Settings.master_vol, func(x: float) -> void:
		Settings.master_vol = x
		Settings.apply_volume())
	_check(g, "الجيروسكوب (التصويب بتحريك الهاتف)", Settings.gyro_on, func(on: bool) -> void: Settings.gyro_on = on)
	_row(g, "حساسية الجيروسكوب", 0.2, 3.0, 0.05, Settings.gyro_sens, func(x: float) -> void: Settings.gyro_sens = x)
	_check(g, "عكس المحور الرأسي", Settings.invert_y, func(on: bool) -> void: Settings.invert_y = on)
	v.add_child(HSeparator.new())
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	v.add_child(hb)
	var bl := UIK.button("تعديل أماكن الأزرار", Vector2(280, 54), 24, Color(0.9, 0.6, 0.15))
	bl.pressed.connect(func() -> void: edit_layout.emit())
	hb.add_child(bl)
	var bc := UIK.button("حفظ وإغلاق", Vector2(220, 54), 24, Color(0.2, 0.75, 0.4))
	bc.pressed.connect(func() -> void:
		Settings.save_all()
		closed.emit())
	hb.add_child(bc)


func _row(g: GridContainer, text: String, lo: float, hi: float, st: float, val: float, cb: Callable) -> void:
	g.add_child(UIK.label(text, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT))
	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := UIK.slider(lo, hi, st, val)
	var l := UIK.label("%.2f" % val, 20, Color(0.8, 0.9, 1.0))
	l.custom_minimum_size = Vector2(70, 0)
	s.value_changed.connect(func(x: float) -> void:
		l.text = ("%d" % int(x)) if st >= 1.0 else ("%.2f" % x)
		cb.call(x))
	if st >= 1.0:
		l.text = "%d" % int(val)
	h.add_child(s)
	h.add_child(l)
	g.add_child(h)


func _check(g: GridContainer, text: String, val: bool, cb: Callable) -> void:
	g.add_child(UIK.label(text, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT))
	var c := CheckButton.new()
	c.button_pressed = val
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool) -> void: cb.call(on))
	g.add_child(c)

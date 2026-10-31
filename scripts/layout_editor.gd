class_name LayoutEditor
extends Control
## محرّر أماكن الأزرار: اسحب أي زر لمكانه، وغيّر حجمه وشفافيته.

signal finished

var tui: TouchUI
var _info: Label
var _size_s: HSlider
var _alpha_s: HSlider
var _sel: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.09, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# مخطط الشاشة
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", UIK.box(Color(0.12, 0.2, 0.3, 0.25), Color(0.4, 0.6, 0.9, 0.6), 2, 0, 0))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	tui = TouchUI.new()
	tui.edit_mode = true
	add_child(tui)
	tui.edit_selected.connect(_on_sel)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UIK.box(Color(0.06, 0.08, 0.12, 0.95), Color(0.25, 0.55, 0.95), 2, 14, 10))
	bar.anchor_left = 0.2
	bar.anchor_right = 0.8
	bar.anchor_top = 0.04
	bar.anchor_bottom = 0.04
	bar.grow_vertical = Control.GROW_DIRECTION_END
	add_child(bar)
	var v := VBoxContainer.new()
	bar.add_child(v)
	v.add_child(UIK.label("اسحب الأزرار لمكانك المفضّل. المس زرًا لتغيير حجمه وشفافيته.", 20, Color(0.8, 0.9, 1.0)))
	_info = UIK.label("لم يُحدَّد زر", 22, Color(1, 0.9, 0.4))
	v.add_child(_info)
	var hs := HBoxContainer.new()
	hs.add_theme_constant_override("separation", 12)
	v.add_child(hs)
	hs.add_child(UIK.label("الحجم", 20))
	_size_s = UIK.slider(0.5, 1.8, 0.05, 1.0)
	_size_s.value_changed.connect(func(x: float) -> void: _apply())
	hs.add_child(_size_s)
	hs.add_child(UIK.label("الشفافية", 20))
	_alpha_s = UIK.slider(0.2, 1.0, 0.05, 0.6)
	_alpha_s.value_changed.connect(func(x: float) -> void: _apply())
	hs.add_child(_alpha_s)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var br := UIK.button("إعادة الافتراضي", Vector2(220, 48), 22, Color(0.85, 0.3, 0.25))
	br.pressed.connect(func() -> void:
		Settings.reset_layout()
		_sel = ""
		_info.text = "لم يُحدَّد زر"
		tui.selected = ""
		tui.queue_redraw())
	hb.add_child(br)
	var bd := UIK.button("تم", Vector2(180, 48), 22, Color(0.2, 0.75, 0.4))
	bd.pressed.connect(func() -> void:
		Settings.save_all()
		finished.emit())
	hb.add_child(bd)


func _on_sel(id: String) -> void:
	_sel = id
	var b := Settings.get_btn(id)
	_size_s.set_value_no_signal(float(b["s"]))
	_alpha_s.set_value_no_signal(float(b["a"]))
	_info.text = "الزر المحدد: " + str(TouchUI.LABELS.get(id, "عصا الحركة"))


func _apply() -> void:
	if _sel == "":
		return
	var b := Settings.get_btn(_sel)
	Settings.set_btn(_sel, float(b["x"]), float(b["y"]), _size_s.value, _alpha_s.value)
	tui.queue_redraw()

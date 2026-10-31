class_name HUD
extends CanvasLayer
## واجهة اللعب: أزرار اللمس، تصويب، صحة، ذخيرة، وقت، نتائج، لوحة اختيار السلاح، سجل القتل...

signal weapon_chosen(id: String)
signal leave_pressed
signal rematch_pressed

var arena: Node
var tui: TouchUI
var menu_open: bool = false
var choose_open: bool = false

var _root: Control
var _cross: Control
var _scope: ColorRect
var _scope_lines: Control
var _hp_bar: ProgressBar
var _hp_lbl: Label
var _ammo_lbl: Label
var _wname_lbl: Label
var _time_lbl: Label
var _board_small: VBoxContainer
var _feed: VBoxContainer
var _hit: Control
var _hit_t: float = 0.0
var _hit_kill: bool = false
var _hit_head: bool = false
var _dmg_dirs: Array = []   # [angle, t]
var _dmg_draw: Control
var _heal_rect: ColorRect
var _hurt_rect: ColorRect
var _choose: Control
var _choose_timer: Label
var _choose_left: float = 0.0
var _choose_default: String = "m4"
var _death: Control
var _death_lbl: Label
var _death_sub: Label
var _toast: Label
var _toast_t: float = 0.0
var _full_board: PanelContainer
var _full_board_box: VBoxContainer
var _menu: Control
var _settings: SettingsPanel
var _editor: LayoutEditor
var _results: Control
var _reload_bar: ProgressBar
var _pl: Player = null
var _spread_vis: float = 0.0
var _last_hp: float = 100.0
var _score_t: float = 0.0
var _scope_on: bool = false


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_scope()
	_build_overlays()
	tui = TouchUI.new()
	_root.add_child(tui)
	tui.button_down.connect(_on_btn_down)
	tui.button_up.connect(_on_btn_up)
	_build_hud()
	_build_choose()
	_build_death()
	_build_menu()
	_build_results()


# ------------------------------------------------------------------ بناء
func _build_scope() -> void:
	_scope = ColorRect.new()
	_scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := ShaderMaterial.new()
	sh.shader = load("res://shaders/scope.gdshader")
	_scope.material = sh
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	_root.add_child(_scope)
	_scope_lines = Control.new()
	_scope_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_lines.visible = false
	_scope_lines.draw.connect(func() -> void:
		var c := _scope_lines.size * 0.5
		var r := _scope_lines.size.y * 0.42
		var col := Color(0, 0, 0, 0.9)
		_scope_lines.draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), col, 2.0)
		_scope_lines.draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), col, 2.0)
		_scope_lines.draw_circle(c, 3.0, Color(1, 0.1, 0.1, 0.9))
		for i in range(1, 6):
			var o := float(i) * r / 6.0
			_scope_lines.draw_line(Vector2(c.x + o, c.y - 6), Vector2(c.x + o, c.y + 6), col, 2.0)
			_scope_lines.draw_line(Vector2(c.x - o, c.y - 6), Vector2(c.x - o, c.y + 6), col, 2.0)
			_scope_lines.draw_line(Vector2(c.x - 6, c.y + o), Vector2(c.x + 6, c.y + o), col, 2.0)
		)
	_root.add_child(_scope_lines)


func _build_overlays() -> void:
	_heal_rect = ColorRect.new()
	_heal_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_heal_rect.color = Color(0.1, 1.0, 0.3, 0.0)
	_heal_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_heal_rect)
	_hurt_rect = ColorRect.new()
	_hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_rect.color = Color(1.0, 0.0, 0.0, 0.0)
	_hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hurt_rect)
	_dmg_draw = Control.new()
	_dmg_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dmg_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dmg_draw.draw.connect(_draw_dmg)
	_root.add_child(_dmg_draw)
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_cross)
	_root.add_child(_cross)
	_hit = Control.new()
	_hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit.draw.connect(_draw_hit)
	_root.add_child(_hit)


func _build_hud() -> void:
	# الصحة (أعلى اليسار)
	var hp_box := VBoxContainer.new()
	hp_box.position = Vector2(26, 18)
	hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hp_box)
	_hp_lbl = UIK.label("100", 30, Color(0.4, 1.0, 0.5), HORIZONTAL_ALIGNMENT_LEFT)
	hp_box.add_child(_hp_lbl)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(250, 16)
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	_hp_bar.show_percentage = false
	_hp_bar.add_theme_stylebox_override("background", UIK.box(Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.5), 1, 6, 0))
	_hp_bar.add_theme_stylebox_override("fill", UIK.box(Color(0.25, 0.85, 0.4), Color(0, 0, 0, 0), 0, 6, 0))
	hp_box.add_child(_hp_bar)
	# سجل القتل
	_feed = VBoxContainer.new()
	_feed.position = Vector2(26, 92)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_feed)
	# الوقت
	_time_lbl = UIK.label("5:00", 40, Color(1, 1, 1))
	_time_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_time_lbl.position.y = 8
	_time_lbl.size = Vector2(160, 50)
	_time_lbl.anchor_left = 0.5
	_time_lbl.anchor_right = 0.5
	_time_lbl.offset_left = -80
	_time_lbl.offset_right = 80
	_time_lbl.offset_top = 8
	_root.add_child(_time_lbl)
	# لوحة مصغّرة (يمين أعلى)
	_board_small = VBoxContainer.new()
	_board_small.anchor_left = 1.0
	_board_small.anchor_right = 1.0
	_board_small.offset_left = -300
	_board_small.offset_right = -76
	_board_small.offset_top = 14
	_board_small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_board_small)
	# الذخيرة والسلاح (أسفل اليمين فوق الأزرار)
	_ammo_lbl = UIK.label("30", 44, Color(1, 0.95, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	_ammo_lbl.anchor_left = 1.0
	_ammo_lbl.anchor_right = 1.0
	_ammo_lbl.anchor_top = 1.0
	_ammo_lbl.anchor_bottom = 1.0
	_ammo_lbl.offset_left = -300
	_ammo_lbl.offset_right = -30
	_ammo_lbl.offset_top = -62
	_ammo_lbl.offset_bottom = -6
	_ammo_lbl.visible = false
	_root.add_child(_ammo_lbl)
	_wname_lbl = UIK.label("", 22, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	_wname_lbl.anchor_left = 1.0
	_wname_lbl.anchor_right = 1.0
	_wname_lbl.anchor_top = 1.0
	_wname_lbl.anchor_bottom = 1.0
	_wname_lbl.offset_left = -300
	_wname_lbl.offset_right = -30
	_wname_lbl.offset_top = -92
	_wname_lbl.offset_bottom = -62
	_root.add_child(_wname_lbl)
	# شريط إعادة التعبئة
	_reload_bar = ProgressBar.new()
	_reload_bar.anchor_left = 0.5
	_reload_bar.anchor_right = 0.5
	_reload_bar.anchor_top = 0.62
	_reload_bar.anchor_bottom = 0.62
	_reload_bar.offset_left = -90
	_reload_bar.offset_right = 90
	_reload_bar.offset_bottom = 10
	_reload_bar.max_value = 1.0
	_reload_bar.show_percentage = false
	_reload_bar.visible = false
	_reload_bar.add_theme_stylebox_override("background", UIK.box(Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.6), 1, 5, 0))
	_reload_bar.add_theme_stylebox_override("fill", UIK.box(Color(1, 0.8, 0.2), Color(0, 0, 0, 0), 0, 5, 0))
	_root.add_child(_reload_bar)
	# زر القائمة
	var mb := UIK.button("II", Vector2(54, 54), 24, Color(0.5, 0.55, 0.65))
	mb.anchor_left = 1.0
	mb.anchor_right = 1.0
	mb.offset_left = -64
	mb.offset_right = -10
	mb.offset_top = 10
	mb.offset_bottom = 64
	mb.pressed.connect(func() -> void:
		Sfx.play("ui", -4.0)
		open_menu())
	_root.add_child(mb)
	# إشعار
	_toast = UIK.label("", 34, Color(1, 0.95, 0.5))
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.2
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.modulate.a = 0.0
	_root.add_child(_toast)
	# لوحة النتائج الكاملة (تُعرض بالضغط المطوّل)
	_full_board = PanelContainer.new()
	_full_board.add_theme_stylebox_override("panel", UIK.box(Color(0.03, 0.05, 0.09, 0.93), Color(0.3, 0.6, 1.0), 2, 16, 18))
	_full_board.anchor_left = 0.5
	_full_board.anchor_right = 0.5
	_full_board.anchor_top = 0.5
	_full_board.anchor_bottom = 0.5
	_full_board.offset_left = -300
	_full_board.offset_right = 300
	_full_board.offset_top = -170
	_full_board.offset_bottom = 170
	_full_board.visible = false
	_full_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_full_board)
	_full_board_box = VBoxContainer.new()
	_full_board.add_child(_full_board_box)


func _build_choose() -> void:
	_choose = Control.new()
	_choose.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choose.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.08, 0.80)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choose.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -560
	v.offset_right = 560
	v.offset_top = -230
	v.offset_bottom = 230
	v.add_theme_constant_override("separation", 14)
	_choose.add_child(v)
	v.add_child(UIK.label("اختر سلاحك", 44, Color(1, 0.9, 0.4)))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	for id in WDB.ORDER:
		h.add_child(_weapon_card(id))
	_choose_timer = UIK.label("", 24, Color(0.8, 0.9, 1.0))
	v.add_child(_choose_timer)
	_root.add_child(_choose)


func _weapon_card(id: String) -> Control:
	var wd: Dictionary = WDB.DATA[id]
	var b := Button.new()
	b.custom_minimum_size = Vector2(262, 330)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UIK.box(Color(0.08, 0.12, 0.2, 0.95), Color(0.3, 0.5, 0.8), 2, 16, 10))
	b.add_theme_stylebox_override("hover", UIK.box(Color(0.12, 0.2, 0.32, 0.98), Color(0.5, 0.8, 1.0), 3, 16, 10))
	b.add_theme_stylebox_override("pressed", UIK.box(Color(0.2, 0.4, 0.2, 1.0), Color(0.5, 1.0, 0.5), 3, 16, 10))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	v.add_child(UIK.label(wd["name"], 34, Color(1, 1, 1)))
	var tr := TextureRect.new()
	tr.texture = load("res://ui/icon_%s.png" % id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(240, 96)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tr)
	var stats := [
		["الضرر", clampf(float(wd["dmg"]) * float(wd["pellets"]) * (1.0 if id != "m1014" else 0.45) / 120.0, 0.05, 1.0)],
		["معدل الإطلاق", clampf(1.0 / float(wd["interval"]) / 12.0, 0.05, 1.0)],
		["المدى", clampf(float(wd["range"]) / 400.0, 0.1, 1.0)],
		["الثبات", clampf(1.0 - float(wd["rec_pitch"]) / 5.0, 0.1, 1.0)],
	]
	for s in stats:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UIK.label(s[0], 17, Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_RIGHT)
		l.custom_minimum_size = Vector2(98, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		var pb := ProgressBar.new()
		pb.max_value = 1.0
		pb.value = s[1]
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(120, 12)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb.add_theme_stylebox_override("background", UIK.box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 0, 4, 0))
		pb.add_theme_stylebox_override("fill", UIK.box(Color(0.3, 0.75, 1.0), Color(0, 0, 0, 0), 0, 4, 0))
		row.add_child(pb)
		v.add_child(row)
	var info := UIK.label("%d طلقة • تعبئة %.1f ث" % [int(wd["mag"]), float(wd["reload"])], 17, Color(1, 0.9, 0.5))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(info)
	b.pressed.connect(func() -> void:
		Sfx.play("ui", -2.0)
		_pick(id))
	return b


func _build_death() -> void:
	_death = Control.new()
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.4, 0.0, 0.0, 0.28)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.add_child(bg)
	_death_lbl = UIK.label("", 46, Color(1, 0.4, 0.35))
	_death_lbl.anchor_left = 0.5
	_death_lbl.anchor_right = 0.5
	_death_lbl.anchor_top = 0.38
	_death_lbl.offset_left = -500
	_death_lbl.offset_right = 500
	_death.add_child(_death_lbl)
	_death_sub = UIK.label("", 28, Color(1, 1, 1))
	_death_sub.anchor_left = 0.5
	_death_sub.anchor_right = 0.5
	_death_sub.anchor_top = 0.5
	_death_sub.offset_left = -500
	_death_sub.offset_right = 500
	_death.add_child(_death_sub)
	_root.add_child(_death)


func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIK.box(Color(0.05, 0.07, 0.1, 0.96), Color(0.25, 0.55, 0.95), 2, 18, 22))
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -190
	p.offset_right = 190
	p.offset_top = -190
	p.offset_bottom = 190
	_menu.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(UIK.label("متوقّف مؤقتًا", 34, Color(0.45, 0.8, 1.0)))
	var b1 := UIK.button("متابعة", Vector2(300, 58), 26, Color(0.2, 0.75, 0.4))
	b1.pressed.connect(close_menu)
	v.add_child(b1)
	var b2 := UIK.button("الإعدادات", Vector2(300, 58), 26)
	b2.pressed.connect(_open_settings)
	v.add_child(b2)
	var b3 := UIK.button("مغادرة المباراة", Vector2(300, 58), 26, Color(0.85, 0.3, 0.25))
	b3.pressed.connect(func() -> void: leave_pressed.emit())
	v.add_child(b3)
	_root.add_child(_menu)


func _build_results() -> void:
	_results = Control.new()
	_results.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.add_child(bg)
	_root.add_child(_results)


# ------------------------------------------------------------------ قائمة/إعدادات
func open_menu() -> void:
	menu_open = true
	_menu.visible = true
	tui.release_all()
	tui.enabled = false


func close_menu() -> void:
	menu_open = false
	_menu.visible = false
	Settings.save_all()
	tui.enabled = true


func _open_settings() -> void:
	_menu.visible = false
	_settings = SettingsPanel.new()
	_settings.anchor_left = 0.5
	_settings.anchor_right = 0.5
	_settings.anchor_top = 0.5
	_settings.anchor_bottom = 0.5
	_settings.offset_left = -430
	_settings.offset_right = 430
	_settings.offset_top = -270
	_settings.offset_bottom = 270
	_settings.build(false)
	_root.add_child(_settings)
	_settings.closed.connect(func() -> void:
		_settings.queue_free()
		_menu.visible = true)
	_settings.edit_layout.connect(func() -> void:
		_settings.visible = false
		_editor = LayoutEditor.new()
		_root.add_child(_editor)
		_editor.finished.connect(func() -> void:
			_editor.queue_free()
			tui.queue_redraw()
			_settings.visible = true))


# ------------------------------------------------------------------ أحداث الأزرار
func _on_btn_down(id: String) -> void:
	if _pl == null or choose_open:
		return
	match id:
		"fire", "fire2":
			_pl.fire_down()
		"ads":
			_pl.toggle_ads()
		"jump":
			_pl.press_jump()
		"crouch":
			_pl.press_crouch()
		"reload":
			_pl.press_reload()
		"score":
			_full_board.visible = true


func _on_btn_up(id: String) -> void:
	if _pl == null:
		return
	match id:
		"fire", "fire2":
			if not tui.is_held("fire") and not tui.is_held("fire2"):
				_pl.fire_up()
		"score":
			_full_board.visible = false


func bind(p: Player) -> void:
	_pl = p
	p.ui = self
	p.tui = tui


# ------------------------------------------------------------------ اختيار السلاح
func show_choose(default_id: String, secs: float = 12.0) -> void:
	choose_open = true
	_choose.visible = true
	_choose_left = secs
	_choose_default = default_id
	tui.release_all()
	tui.visible = false


func _pick(id: String) -> void:
	if not choose_open:
		return
	choose_open = false
	_choose.visible = false
	tui.visible = true
	weapon_chosen.emit(id)


func hide_choose() -> void:
	choose_open = false
	_choose.visible = false
	tui.visible = true


# ------------------------------------------------------------------ تحديث دوري
func update_state(p: Player) -> void:
	_pl = p
	_hp_bar.value = p.hp
	_hp_lbl.text = "%d" % int(ceil(p.hp))
	var hc := Color(0.25, 0.85, 0.4) if p.hp > 50.0 else (Color(0.95, 0.75, 0.2) if p.hp > 25.0 else Color(0.95, 0.25, 0.2))
	_hp_lbl.add_theme_color_override("font_color", hc)
	_ammo_lbl.visible = true
	_ammo_lbl.text = "%d / %d" % [p.ammo, int(p.wd["mag"])]
	_ammo_lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.3) if p.ammo <= int(p.wd["mag"]) * 0.2 else Color(1, 0.95, 0.7))
	_wname_lbl.text = str(p.wd["name"])
	tui.ads_active = p.ads
	var scoped: bool = bool(p.wd["scope"]) and p.ads_t > 0.82 and p.alive
	if scoped != _scope_on:
		_scope_on = scoped
		_scope.visible = scoped
		_scope_lines.visible = scoped
		_scope_lines.queue_redraw()
	_reload_bar.visible = p.reloading
	if p.reloading:
		_reload_bar.value = p._reload_t / p._reload_total
	_spread_vis = lerpf(_spread_vis, p._spread_now, 0.3)
	_cross.queue_redraw()
	if p.hp < _last_hp - 0.5:
		_hurt_rect.color.a = clampf((_last_hp - p.hp) / 60.0 + 0.15, 0.0, 0.5)
	_last_hp = p.hp
	_hurt_rect.color.a = lerpf(_hurt_rect.color.a, 0.0, 0.06)
	_heal_rect.color.a = lerpf(_heal_rect.color.a, 0.22 if p.take_heal_flash() else 0.0, 0.15)
	_time_lbl.text = UIK.format_time(Net.time_left)
	_time_lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.3) if Net.time_left < 30.0 else Color.WHITE)


func _process(delta: float) -> void:
	if choose_open:
		_choose_left -= delta
		_choose_timer.text = "اختيار تلقائي بعد %d ث" % maxi(0, int(ceil(_choose_left)))
		if _choose_left <= 0.0:
			_pick(_choose_default)
	if _hit_t > 0.0:
		_hit_t -= delta
		_hit.queue_redraw()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
	var changed := false
	for d in _dmg_dirs:
		d[1] -= delta
	while _dmg_dirs.size() > 0 and _dmg_dirs[0][1] <= 0.0:
		_dmg_dirs.pop_front()
		changed = true
	if _dmg_dirs.size() > 0 or changed:
		_dmg_draw.queue_redraw()
	_score_t -= delta
	if _score_t <= 0.0:
		_score_t = 0.5
		refresh_scores()


func refresh_scores() -> void:
	var arr: Array = []
	for id in Net.players:
		arr.append([id, Net.players[id]])
	arr.sort_custom(func(a, b) -> bool: return a[1]["kills"] > b[1]["kills"])
	for c in _board_small.get_children():
		c.queue_free()
	for e in arr:
		var l := UIK.label("%s — %d كيل" % [e[1]["name"], int(e[1]["kills"])], 20, Color(1, 0.9, 0.4) if e[0] == Net.my_id() else Color(1, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board_small.add_child(l)
	if _full_board.visible:
		for c in _full_board_box.get_children():
			c.queue_free()
		_full_board_box.add_child(UIK.label("النتائج", 34, Color(0.45, 0.8, 1.0)))
		var rank := 1
		for e in arr:
			var l2 := UIK.label("%d.  %s — %d كيل   (موت %d)" % [rank, e[1]["name"], int(e[1]["kills"]), int(e[1]["deaths"])], 28, Color(1, 0.9, 0.4) if e[0] == Net.my_id() else Color(1, 1, 1))
			_full_board_box.add_child(l2)
			rank += 1


# ------------------------------------------------------------------ رسم
func _draw_cross() -> void:
	if _pl == null or _scope_on or not _pl.alive or choose_open:
		return
	var c := _cross.size * 0.5
	var px_per_deg := _cross.size.y / maxf(_pl.cam.fov, 1.0)
	var gap := 5.0 + _spread_vis * px_per_deg
	var ln := 11.0
	var col := Color(1, 1, 1, 0.9)
	var sh := Color(0, 0, 0, 0.6)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_cross.draw_line(c + d * gap + Vector2(1, 1), c + d * (gap + ln) + Vector2(1, 1), sh, 4.0)
		_cross.draw_line(c + d * gap, c + d * (gap + ln), col, 2.5)
	_cross.draw_circle(c, 1.8, Color(1, 0.2, 0.2, 0.9))


func hitmarker(kill: bool, head: bool) -> void:
	_hit_t = 0.28 if not kill else 0.55
	_hit_kill = kill
	_hit_head = head
	Sfx.play("kill" if kill else ("headshot" if head else "hit"), -2.0)


func _draw_hit() -> void:
	if _hit_t <= 0.0:
		return
	var c := _hit.size * 0.5
	var a := clampf(_hit_t * 4.0, 0.0, 1.0)
	var col := Color(1, 0.15, 0.1, a) if _hit_kill else (Color(1, 0.8, 0.2, a) if _hit_head else Color(1, 1, 1, a))
	var o := 10.0 + (1.0 - clampf(_hit_t / 0.28, 0.0, 1.0)) * 6.0
	var l := 14.0
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		_hit.draw_line(c + d * o, c + d * (o + l), col, 3.5)


func damage_from(angle_rad: float) -> void:
	_dmg_dirs.append([angle_rad, 1.2])
	_dmg_draw.queue_redraw()


func _draw_dmg() -> void:
	var c := _dmg_draw.size * 0.5
	for d in _dmg_dirs:
		var a: float = clampf(d[1] / 1.2, 0.0, 1.0)
		var ang: float = d[0] - PI * 0.5
		var r := _dmg_draw.size.y * 0.30
		_dmg_draw.draw_arc(c, r, ang - 0.28, ang + 0.28, 12, Color(1, 0.1, 0.05, a * 0.9), 14.0, true)


func on_fire(p: Player) -> void:
	pass


# ------------------------------------------------------------------ رسائل
func toast(text: String, secs: float = 2.2) -> void:
	_toast.text = text
	_toast_t = secs
	_toast.modulate.a = 1.0


func add_feed(text: String, mine: bool) -> void:
	var l := UIK.label(text, 21, Color(1, 0.9, 0.4) if mine else Color(1, 1, 1), HORIZONTAL_ALIGNMENT_LEFT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.add_child(l)
	while _feed.get_child_count() > 5:
		_feed.get_child(0).queue_free()
		_feed.remove_child(_feed.get_child(0))
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(l):
			l.queue_free())


func show_death(killer: String, secs: float) -> void:
	_death.visible = true
	_death_lbl.text = ("قتلك " + killer) if killer != "" else "لقد متّ"
	_death_sub.text = "العودة خلال %d ثانية..." % int(ceil(secs))


func update_death(secs: float) -> void:
	_death_sub.text = "العودة خلال %d ثانية..." % int(ceil(secs))


func hide_death() -> void:
	_death.visible = false


func show_results(rows: Array, is_host: bool) -> void:
	for c in _results.get_children():
		if c is Control and c is not ColorRect:
			c.queue_free()
	tui.release_all()
	tui.visible = false
	_results.visible = true
	var v := VBoxContainer.new()
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -330
	v.offset_right = 330
	v.offset_top = -270
	v.offset_bottom = 270
	v.add_theme_constant_override("separation", 12)
	_results.add_child(v)
	var title := "انتهت المباراة"
	v.add_child(UIK.label(title, 50, Color(1, 0.9, 0.4)))
	if rows.size() > 0:
		var best: int = rows[0]["kills"]
		var winners: Array = []
		for r in rows:
			if r["kills"] == best:
				winners.append(r["name"])
		var wt := ("الفائز: " + "، ".join(winners)) if winners.size() == 1 else ("تعادل: " + "، ".join(winners))
		v.add_child(UIK.label(wt, 38, Color(0.4, 1.0, 0.55)))
	var rank := 1
	for r in rows:
		var l := UIK.label("%d.  %s — %d كيل" % [rank, r["name"], int(r["kills"])], 32, Color(1, 0.9, 0.4) if r["id"] == Net.my_id() else Color.WHITE)
		v.add_child(l)
		rank += 1
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	v.add_child(hb)
	if is_host:
		var b := UIK.button("جولة جديدة", Vector2(240, 60), 26, Color(0.2, 0.75, 0.4))
		b.pressed.connect(func() -> void: rematch_pressed.emit())
		hb.add_child(b)
	else:
		hb.add_child(UIK.label("بانتظار المضيف...", 24, Color(0.8, 0.9, 1.0)))
	var b2 := UIK.button("خروج", Vector2(200, 60), 26, Color(0.85, 0.3, 0.25))
	b2.pressed.connect(func() -> void: leave_pressed.emit())
	hb.add_child(b2)

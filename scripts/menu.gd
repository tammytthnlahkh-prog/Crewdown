extends Control
## القائمة الرئيسية: استضافة / انضمام / شخصية / إعدادات / شكر.

var _content: Control
var _status: Label
var _roster_box: VBoxContainer
var _rooms_box: VBoxContainer
var _ip_edit: LineEdit
var _start_btn: Button
var _settings: SettingsPanel
var _editor: LayoutEditor
var _t: float = 0.0
var _bg: ColorRect

const CREDITS := [
	"خريطة The Skeld — Pablopcb (CC-BY-4.0)",
	"M4 — Pieter Ferreira (CC-BY-4.0)",
	"AKM — Armored Wave (CC-BY-4.0)",
	"AWM — GoldbergR (CC-BY-4.0)",
	"M1014 — ROCK FF 99 (Sketchfab Standard)",
	"اليدان First Person Hands — DavidFischer (CC-BY-4.0)",
	"شخصية المومياء — DFLEX (CC-BY-4.0)",
	"Bullets — MarcosBritoJR (CC-BY-4.0)",
	"Bullet Set — HarisonKilgour (CC-BY-4.0)",
	"مشروع شخصي غير تجاري. Among Us و PUBG علامات تجارية لأصحابها.",
]


func _ready() -> void:
	Net.start_listening()
	Net.roster_changed.connect(_refresh_roster)
	Net.rooms_changed.connect(_refresh_rooms)
	Net.join_failed.connect(func(r: String) -> void:
		_set_status(r, true)
		_show_main())
	Net.left_room.connect(func() -> void:
		_show_main())
	_bg = ColorRect.new()
	_bg.color = Color(0.03, 0.05, 0.1)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	var logo := TextureRect.new()
	logo.texture = load("res://ui/logo.jpg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.modulate = Color(1, 1, 1, 0.22)
	add_child(logo)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_content)
	_status = UIK.label("", 24, Color(1, 0.8, 0.4))
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.anchor_left = 0.0
	_status.anchor_right = 1.0
	_status.offset_top = -48
	add_child(_status)
	if Net.online and Net.in_match == false and Net.players.size() > 0:
		_show_lobby()
	else:
		_show_main()


func _set_status(t: String, bad: bool = false) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if bad else Color(0.6, 1.0, 0.7))


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func _center_box(w: float = 420) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -w * 0.5
	v.offset_right = w * 0.5
	v.offset_top = -300
	v.offset_bottom = 300
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	_content.add_child(v)
	return v


func _title(v: Control, sub: String = "") -> void:
	var t := UIK.label("CREWDOWN REALM", 58, Color(0.45, 0.8, 1.0))
	v.add_child(t)
	if sub != "":
		v.add_child(UIK.label(sub, 26, Color(0.8, 0.85, 0.95)))


# ------------------------------------------------------------------ الصفحات
func _show_main() -> void:
	_clear()
	Net.start_listening()
	var v := _center_box()
	_title(v, "لعبة قتال جماعي عبر الواي فاي")
	v.add_child(Control.new())
	var b1 := UIK.button("إنشاء غرفة", Vector2(420, 62), 28, Color(0.2, 0.75, 0.4))
	b1.pressed.connect(_on_host)
	v.add_child(b1)
	var b2 := UIK.button("انضمام إلى غرفة", Vector2(420, 62), 28)
	b2.pressed.connect(_show_join)
	v.add_child(b2)
	var b3 := UIK.button("الشخصية", Vector2(420, 62), 28, Color(0.75, 0.5, 0.9))
	b3.pressed.connect(_show_char)
	v.add_child(b3)
	var b4 := UIK.button("الإعدادات", Vector2(420, 62), 28, Color(0.9, 0.6, 0.15))
	b4.pressed.connect(_show_settings)
	v.add_child(b4)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var b5 := UIK.button("الشكر والمصادر", Vector2(204, 50), 22, Color(0.5, 0.55, 0.65))
	b5.pressed.connect(_show_credits)
	h.add_child(b5)
	var b6 := UIK.button("خروج", Vector2(204, 50), 22, Color(0.85, 0.3, 0.25))
	b6.pressed.connect(func() -> void: get_tree().quit())
	h.add_child(b6)
	v.add_child(UIK.label("اسمك: " + Settings.player_name, 22, Color(1, 0.9, 0.4)))


func _on_host() -> void:
	Sfx.play("ui", -4.0)
	var nm := Settings.player_name
	if not Net.host_game("غرفة " + nm):
		_set_status("تعذّر إنشاء الغرفة (المنفذ مشغول؟)", true)
		return
	_set_status("الغرفة جاهزة — اطلب من أصدقائك الانضمام", false)
	_show_lobby()


func _show_lobby() -> void:
	_clear()
	var v := _center_box(620)
	_title(v)
	var ips := ", ".join(Net.local_ips())
	if Net.is_host:
		v.add_child(UIK.label("عنوانك للانضمام اليدوي: " + (ips if ips != "" else "غير متاح"), 24, Color(0.7, 1.0, 0.8)))
	else:
		v.add_child(UIK.label("متّصل بالغرفة", 26, Color(0.7, 1.0, 0.8)))
	v.add_child(UIK.label("اللاعبون (حتى 4)", 26, Color(1, 0.9, 0.4)))
	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 6)
	v.add_child(_roster_box)
	_refresh_roster()
	if Net.is_host:
		_start_btn = UIK.button("ابدأ المباراة (5 دقائق)", Vector2(420, 62), 28, Color(0.2, 0.75, 0.4))
		_start_btn.pressed.connect(func() -> void:
			Sfx.play("ui", -4.0)
			Net.start_match())
		v.add_child(_start_btn)
	else:
		v.add_child(UIK.label("بانتظار المضيف ليبدأ المباراة...", 26, Color(0.8, 0.9, 1.0)))
	var b := UIK.button("مغادرة", Vector2(240, 54), 24, Color(0.85, 0.3, 0.25))
	b.pressed.connect(func() -> void:
		Net.leave()
		_show_main())
	v.add_child(b)


func _refresh_roster() -> void:
	if _roster_box == null or not is_instance_valid(_roster_box):
		return
	for c in _roster_box.get_children():
		c.queue_free()
	for id in Net.players:
		var p: Dictionary = Net.players[id]
		var tag := " (المضيف)" if id == 1 else ""
		var chr := "فتاة" if p["character"] == "girl" else "مومياء"
		var l := UIK.label("%s%s — %s" % [p["name"], tag, chr], 28, Color.WHITE)
		_roster_box.add_child(l)


func _show_join() -> void:
	_clear()
	var v := _center_box(620)
	_title(v, "ابحث عن غرفة")
	v.add_child(UIK.label("الغرف القريبة على نفس الواي فاي/الهوت سبوت:", 22, Color(0.8, 0.9, 1.0)))
	_rooms_box = VBoxContainer.new()
	_rooms_box.add_theme_constant_override("separation", 8)
	_rooms_box.custom_minimum_size = Vector2(0, 150)
	v.add_child(_rooms_box)
	_refresh_rooms()
	v.add_child(UIK.label("أو أدخل عنوان المضيف يدويًا:", 22, Color(0.8, 0.9, 1.0)))
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "مثال 192.168.1.5"
	_ip_edit.text = Settings.last_ip
	_ip_edit.custom_minimum_size = Vector2(420, 50)
	_ip_edit.add_theme_font_size_override("font_size", 26)
	v.add_child(_ip_edit)
	var b := UIK.button("اتصال", Vector2(260, 56), 26, Color(0.2, 0.75, 0.4))
	b.pressed.connect(func() -> void: _join(_ip_edit.text))
	v.add_child(b)
	var back := UIK.button("رجوع", Vector2(200, 50), 22, Color(0.5, 0.55, 0.65))
	back.pressed.connect(_show_main)
	v.add_child(back)


func _refresh_rooms() -> void:
	if _rooms_box == null or not is_instance_valid(_rooms_box):
		return
	for c in _rooms_box.get_children():
		c.queue_free()
	if Net.found_rooms.is_empty():
		_rooms_box.add_child(UIK.label("جارٍ البحث...", 22, Color(0.7, 0.7, 0.75)))
	for ip in Net.found_rooms:
		var r: Dictionary = Net.found_rooms[ip]
		var b := UIK.button("%s  (%d/4)  %s" % [r["name"], int(r["count"]), "— جارية" if r.get("match", false) else ""], Vector2(520, 54), 24, Color(0.3, 0.6, 0.95))
		var addr: String = ip
		b.pressed.connect(func() -> void: _join(addr))
		_rooms_box.add_child(b)


func _join(ip: String) -> void:
	ip = ip.strip_edges()
	if ip == "":
		_set_status("أدخل العنوان", true)
		return
	Settings.last_ip = ip
	Settings.save_all()
	_set_status("جارٍ الاتصال بـ " + ip + " ...", false)
	if Net.join_game(ip):
		_show_wait()


func _show_wait() -> void:
	_clear()
	var v := _center_box(560)
	_title(v)
	v.add_child(UIK.label("جارٍ الدخول إلى الغرفة...", 30, Color(0.8, 0.9, 1.0)))
	_roster_box = VBoxContainer.new()
	v.add_child(_roster_box)
	var timer := get_tree().create_timer(10.0)
	timer.timeout.connect(func() -> void:
		if Net.online and Net.players.is_empty():
			Net.leave()
			_set_status("انتهت مهلة الاتصال", true)
			_show_main())
	Net.roster_changed.connect(_on_roster_joined, CONNECT_ONE_SHOT)


func _on_roster_joined() -> void:
	if Net.players.has(Net.my_id()) and not Net.in_match:
		_show_lobby()


func _show_char() -> void:
	_clear()
	var v := _center_box(760)
	_title(v, "اختر شخصيتك — يراك الآخرون بها")
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	h.add_child(_char_card("mummy"))
	v.add_child(UIK.label("شخصيات إضافية قريبًا (شخصية الفتاة تحتاج إعادة تصدير الموديل لتعمل بشكل صحيح).", 20, Color(0.8, 0.85, 0.95)))
	var back := UIK.button("رجوع", Vector2(200, 50), 22, Color(0.5, 0.55, 0.65))
	back.pressed.connect(func() -> void:
		Settings.save_all()
		_show_main())
	v.add_child(back)


func _char_card(kind: String) -> Control:
	var sel := Settings.character == kind
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIK.box(Color(0.08, 0.12, 0.2, 0.95), Color(0.3, 1.0, 0.5) if sel else Color(0.3, 0.5, 0.8), 4 if sel else 2, 16, 10))
	var v := VBoxContainer.new()
	pc.add_child(v)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(300, 330)
	svc.stretch = true
	var sv := SubViewport.new()
	sv.size = Vector2i(300, 330)
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.1)
	cam.fov = 38
	sv.add_child(cam)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-30, 20, 0)
	sv.add_child(l)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.7
	env.environment = e
	sv.add_child(env)
	var cm := CharModel.new()
	sv.add_child(cm)
	cm.build(kind)
	cm.rotation.y = 0.0
	cm.set_weapon("m4")
	cm.set_process(true)
	var spin := Node3D.new()
	sv.add_child(spin)
	cm.set_meta("spin", true)
	get_tree().process_frame.connect(func() -> void:
		if is_instance_valid(cm):
			cm.rotation.y += 0.01, CONNECT_REFERENCE_COUNTED)
	v.add_child(svc)
	var name_l := UIK.label("المومياء" if kind == "mummy" else "الفتاة", 30, Color.WHITE)
	v.add_child(name_l)
	var b := UIK.button("مختارة" if sel else "اختيار", Vector2(240, 50), 24, Color(0.2, 0.75, 0.4) if sel else Color(0.3, 0.6, 0.95))
	b.pressed.connect(func() -> void:
		Settings.character = kind
		Settings.save_all()
		Sfx.play("ui", -4.0)
		_show_char())
	v.add_child(b)
	return pc


func _show_settings() -> void:
	_clear()
	_settings = SettingsPanel.new()
	_settings.anchor_left = 0.5
	_settings.anchor_right = 0.5
	_settings.anchor_top = 0.5
	_settings.anchor_bottom = 0.5
	_settings.offset_left = -440
	_settings.offset_right = 440
	_settings.offset_top = -290
	_settings.offset_bottom = 290
	_settings.build(true)
	_content.add_child(_settings)
	_settings.closed.connect(_show_main)
	_settings.edit_layout.connect(func() -> void:
		_settings.visible = false
		_editor = LayoutEditor.new()
		_content.add_child(_editor)
		_editor.finished.connect(func() -> void:
			_editor.queue_free()
			_settings.visible = true))


func _show_credits() -> void:
	_clear()
	var v := _center_box(900)
	_title(v, "الشكر والمصادر")
	for c in CREDITS:
		v.add_child(UIK.label(c, 21, Color(0.85, 0.9, 1.0)))
	var back := UIK.button("رجوع", Vector2(200, 50), 22, Color(0.5, 0.55, 0.65))
	back.pressed.connect(_show_main)
	v.add_child(back)

class_name TouchUI
extends Control
## أزرار اللمس: عصا حركة + نار + تصويب + قفز + انحناء + تعبئة + نتيجة.
## وضع التعديل يسمح بسحب كل زر وتغيير حجمه وشفافيته (يُحفظ في الإعدادات).

signal button_down(id: String)
signal button_up(id: String)
signal edit_selected(id: String)

const IDS := ["joystick", "fire", "fire2", "ads", "jump", "crouch", "reload", "score"]
const BASE_R := {"joystick": 105.0, "fire": 74.0, "fire2": 58.0, "ads": 52.0, "jump": 54.0, "crouch": 48.0, "reload": 46.0, "score": 34.0}
const LABELS := {"fire": "نار", "fire2": "نار", "ads": "تصويب", "jump": "قفز", "crouch": "انحناء", "reload": "تعبئة", "score": "النتائج"}

var edit_mode: bool = false
var enabled: bool = true
var stick_vec: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO       # بكسلات تراكمت منذ آخر قراءة
var held: Dictionary = {}
var selected: String = ""
var ads_active: bool = false                 # يلوّن زر التصويب
var _touch: Dictionary = {}                  # index -> {"k": kind, "id": id, "last": Vector2}
var _stick_touch: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_cur: Vector2 = Vector2.ZERO
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	resized.connect(queue_redraw)


func _vs() -> Vector2:
	if size.x > 10.0 and size.y > 10.0:
		return size
	return get_viewport_rect().size


func center_of(id: String) -> Vector2:
	var b := Settings.get_btn(id)
	var s := _vs()
	return Vector2(float(b["x"]) * s.x, float(b["y"]) * s.y)


func radius_of(id: String) -> float:
	var b := Settings.get_btn(id)
	return float(BASE_R[id]) * float(b["s"])


func take_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d


func is_held(id: String) -> bool:
	return held.get(id, false)


func _press(id: String) -> void:
	held[id] = true
	button_down.emit(id)


func _release(id: String) -> void:
	held[id] = false
	button_up.emit(id)


func release_all() -> void:
	for t in _touch.keys():
		var d: Dictionary = _touch[t]
		if d["k"] == "btn":
			_release(d["id"])
	_touch.clear()
	stick_vec = Vector2.ZERO
	_stick_touch = -1
	queue_redraw()


func _hit(pos: Vector2) -> String:
	var best := ""
	var bd := 1e9
	for id in IDS:
		var c := center_of(id)
		var r := radius_of(id) * (1.35 if id == "joystick" else 1.12)
		var d := pos.distance_to(c)
		if d <= r and d < bd:
			bd = d
			best = id
	return best


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var id := _hit(e.position)
			if edit_mode:
				if id != "":
					_touch[e.index] = {"k": "drag", "id": id, "last": e.position}
					selected = id
					edit_selected.emit(id)
					queue_redraw()
				return
			if id == "joystick":
				_touch[e.index] = {"k": "stick", "id": id, "last": e.position}
				_stick_touch = e.index
				_stick_origin = center_of("joystick")
				_stick_cur = e.position
				_update_stick()
			elif id != "":
				_touch[e.index] = {"k": "btn", "id": id, "last": e.position}
				_press(id)
			elif e.position.x > _vs().x * 0.28:
				_touch[e.index] = {"k": "look", "id": "", "last": e.position}
			queue_redraw()
		else:
			if _touch.has(e.index):
				var d: Dictionary = _touch[e.index]
				if d["k"] == "btn":
					_release(d["id"])
				elif d["k"] == "stick":
					stick_vec = Vector2.ZERO
					_stick_touch = -1
				_touch.erase(e.index)
				queue_redraw()
	elif event is InputEventScreenDrag:
		var e2 := event as InputEventScreenDrag
		if not _touch.has(e2.index):
			return
		var d2: Dictionary = _touch[e2.index]
		match d2["k"]:
			"look":
				look_delta += e2.relative
			"stick":
				_stick_cur = e2.position
				_update_stick()
			"drag":
				var id2: String = d2["id"]
				var nx := clampf(e2.position.x / _vs().x, 0.04, 0.96)
				var ny := clampf(e2.position.y / _vs().y, 0.06, 0.94)
				var b := Settings.get_btn(id2)
				Settings.set_btn(id2, nx, ny, float(b["s"]), float(b["a"]))
				queue_redraw()
		d2["last"] = e2.position


func _update_stick() -> void:
	var R := radius_of("joystick")
	var v := (_stick_cur - _stick_origin) / R
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < 0.12:
		v = Vector2.ZERO
	stick_vec = v
	queue_redraw()


# ------------------------------------------------------------------ رسم
func _draw() -> void:
	for id in IDS:
		var c := center_of(id)
		var r := radius_of(id)
		var a := float(Settings.get_btn(id)["a"])
		if id == "joystick":
			draw_circle(c, r, Color(1, 1, 1, 0.10 * a * 2.0))
			draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.55 * a * 1.4), 2.5, true)
			var knob := c + stick_vec * r * 0.7
			draw_circle(knob, r * 0.42, Color(1, 1, 1, 0.38 * a * 1.4))
			draw_arc(knob, r * 0.42, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * a), 2.0, true)
			if edit_mode:
				_edit_ring(id, c, r)
			continue
		var down: bool = held.get(id, false) or (id == "ads" and ads_active)
		var col := Color(1, 1, 1, a)
		var fill := Color(0.1, 0.1, 0.12, 0.45 * a * 1.6)
		if down:
			fill = Color(0.95, 0.75, 0.2, 0.55 * a * 1.6)
		if id == "fire" or id == "fire2":
			fill = Color(0.9, 0.18, 0.12, (0.62 if down else 0.38) * a * 1.5)
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.75 * a * 1.3), 2.5, true)
		_icon(id, c, r, col)
		if edit_mode:
			_edit_ring(id, c, r)


func _edit_ring(id: String, c: Vector2, r: float) -> void:
	if id == selected:
		draw_arc(c, r + 8.0, 0.0, TAU, 48, Color(0.2, 1.0, 0.5, 0.95), 4.0, true)
	else:
		draw_arc(c, r + 5.0, 0.0, TAU, 48, Color(1.0, 1.0, 0.3, 0.6), 2.0, true)


func _icon(id: String, c: Vector2, r: float, col: Color) -> void:
	var lw := maxf(2.5, r * 0.07)
	match id:
		"fire", "fire2":
			# رصاصة
			var w := r * 0.22
			var pts := PackedVector2Array([c + Vector2(-w, r * 0.38), c + Vector2(-w, -r * 0.1), c + Vector2(0, -r * 0.42), c + Vector2(w, -r * 0.1), c + Vector2(w, r * 0.38)])
			draw_colored_polygon(pts, Color(col.r, col.g, col.b, col.a * 0.95))
			draw_line(c + Vector2(-w, r * 0.22), c + Vector2(w, r * 0.22), Color(0.9, 0.18, 0.12, col.a), lw)
		"ads":
			draw_arc(c, r * 0.42, 0.0, TAU, 28, col, lw, true)
			draw_line(c + Vector2(-r * 0.62, 0), c + Vector2(-r * 0.2, 0), col, lw)
			draw_line(c + Vector2(r * 0.62, 0), c + Vector2(r * 0.2, 0), col, lw)
			draw_line(c + Vector2(0, -r * 0.62), c + Vector2(0, -r * 0.2), col, lw)
			draw_line(c + Vector2(0, r * 0.62), c + Vector2(0, r * 0.2), col, lw)
			draw_circle(c, lw * 0.9, col)
		"jump":
			draw_line(c + Vector2(0, r * 0.4), c + Vector2(0, -r * 0.35), col, lw * 1.2)
			draw_line(c + Vector2(-r * 0.32, -r * 0.05), c + Vector2(0, -r * 0.38), col, lw * 1.2)
			draw_line(c + Vector2(r * 0.32, -r * 0.05), c + Vector2(0, -r * 0.38), col, lw * 1.2)
		"crouch":
			draw_line(c + Vector2(-r * 0.36, -r * 0.18), c + Vector2(0, r * 0.18), col, lw * 1.2)
			draw_line(c + Vector2(r * 0.36, -r * 0.18), c + Vector2(0, r * 0.18), col, lw * 1.2)
			draw_line(c + Vector2(-r * 0.36, r * 0.34), c + Vector2(r * 0.36, r * 0.34), col, lw)
		"reload":
			draw_arc(c, r * 0.4, -0.5, TAU - 1.0, 24, col, lw * 1.2, true)
			var tip := c + Vector2(cos(-0.5), sin(-0.5)) * r * 0.4
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.05, -r * 0.2), tip + Vector2(r * 0.22, r * 0.02), tip + Vector2(-r * 0.12, r * 0.12)]), col)
		"score":
			for i in 3:
				draw_line(c + Vector2(-r * 0.45, (i - 1) * r * 0.32), c + Vector2(r * 0.45, (i - 1) * r * 0.32), col, lw)

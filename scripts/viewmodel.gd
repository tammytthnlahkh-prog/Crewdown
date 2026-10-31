class_name ViewModel
extends Node3D
## يدان + سلاح بمنظور اللاعب. الذراعان تُحَلّان بـ IK ليمسكا السلاح فعلًا،
## مع اهتزاز حركة، تمايل مع الالتفاف، ارتداد، وإعادة تعبئة متحرّكة.

const HANDS_SCALE := 0.0185
const PALM_BACK := 0.08

var wid: String = ""
var wd: Dictionary = {}
var weapon: Node3D
var hands: Node3D
var sk: Skeleton3D
var flash: MeshInstance3D
var flash_t: float = 0.0

var ads: float = 0.0              # 0..1
var kick_pos: float = 0.0         # دفع للخلف
var kick_pitch: float = 0.0       # رفع الفوهة (راديان)
var kick_roll: float = 0.0
var reload_p: float = -1.0        # تقدّم إعادة التعبئة 0..1
var reload_len: float = 2.0
var cycle_p: float = -1.0         # مرحلة السحب (AWM) / الـ pump (M1014)
var cycle_len: float = 1.0
var equip_p: float = 1.0
var sprint: float = 0.0
var wall: float = 0.0
var hide_weapon: bool = false

var _sway := Vector2.ZERO
var _bob_t: float = 0.0
var _bob_amp: float = 0.0
var _bones := {}
var _rest_t := {}      # side -> Vector3 (محور اللف)
var _rest_frame := {}  # side -> Basis
var _fingers := {"R": [], "L": []}
var _rest_global := {}
var _shoulder_view := {"R": Vector3(0.22, -0.62, -0.20), "L": Vector3(0.03, -0.62, -0.20)}
var _lookd := Vector2.ZERO
var _debug_pose: Dictionary = {}
var _rest_hand_cache := {}


func _ready() -> void:
	_build_hands()


func _build_hands() -> void:
	hands = (load("res://models/hands/scene.gltf") as PackedScene).instantiate()
	hands.scale = Vector3.ONE * HANDS_SCALE
	hands.rotation_degrees.y = 180.0
	add_child(hands)
	sk = hands.find_children("*", "Skeleton3D", true, false)[0]
	for m in hands.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 4.0
	for side in ["R", "L"]:
		var s: String = side
		_bones[s] = {
			"upper": IK.find_bone(sk, "upper_arm.%s" % s),
			"fore": IK.find_bone(sk, "forearm.%s_0" % s, PackedStringArray([".001", "end"])),
			"wrist": IK.find_bone(sk, "forearm.%s_end" % s),
			"hand": IK.find_bone(sk, "hand.%s" % s),
			"hroot": IK.find_bone(sk, "forearm.%s.001" % s),
			"mid_end": IK.find_bone(sk, "f_middle.03.%s_end" % s),
			"pinky": IK.find_bone(sk, "palm_pinky.%s" % s),
			"index": IK.find_bone(sk, "palm_index.%s" % s),
		}
	await get_tree().process_frame
	sk.reset_bone_poses()
	for side in ["R", "L"]:
		var b: Dictionary = _bones[side]
		var f: Vector3 = sk.get_bone_global_pose(b["mid_end"]).origin - sk.get_bone_global_pose(b["hand"]).origin
		var t: Vector3 = sk.get_bone_global_pose(b["index"]).origin - sk.get_bone_global_pose(b["pinky"]).origin
		_rest_frame[side] = IK.frame(f, t)
		_rest_t[side] = (t - f.normalized() * t.dot(f.normalized())).normalized()
		_rest_hand_cache[b["hroot"]] = sk.get_bone_global_pose(b["hroot"]).basis
		for fn in ["pinky", "ring", "middle", "index"]:
			for j in [1, 2, 3]:
				var idx := IK.find_bone(sk, "f_%s.0%d.%s" % [fn, j, side], PackedStringArray(["end"]))
				if idx >= 0:
					_fingers[side].append({"i": idx, "j": j, "n": fn})
					_rest_global[idx] = sk.get_bone_global_pose(idx).basis
	# ضع الكتفين في مكانهما أمام الكاميرا
	var sh_r := sk.global_transform * sk.get_bone_global_pose(_bones["R"]["upper"]).origin
	var sh_l := sk.global_transform * sk.get_bone_global_pose(_bones["L"]["upper"]).origin
	var mid := (sh_r + sh_l) * 0.5
	var want: Vector3 = ((_shoulder_view["R"] as Vector3) + (_shoulder_view["L"] as Vector3)) * 0.5
	hands.position += want - mid
	if wid != "":
		set_weapon(wid)


func set_weapon(id: String) -> void:
	wid = id
	wd = WDB.DATA[id]
	if weapon:
		weapon.queue_free()
	weapon = WeaponModel.make(id)
	add_child(weapon)
	# وميض الفوهة
	flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	flash.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _flash_tex()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash.material_override = m
	flash.position = wd["muzzle"] + Vector3(0, 0, -0.04)
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon.add_child(flash)
	equip_p = 0.0
	reload_p = -1.0
	cycle_p = -1.0
	ads = 0.0


static var _ftex: Texture2D
static func _flash_tex() -> Texture2D:
	if _ftex:
		return _ftex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			var ang := atan2(y - 31.5, x - 31.5)
			a *= 0.6 + 0.4 * absf(sin(ang * 4.0))
			img.set_pixel(x, y, Color(1.0, 0.8, 0.4, a))
	_ftex = ImageTexture.create_from_image(img)
	return _ftex


func fire_visual() -> void:
	kick_pos += wd["kick_back"] * (0.55 if ads > 0.5 else 1.0)
	kick_pitch += deg_to_rad(float(wd["rec_pitch"]) * 0.45) * (0.5 if ads > 0.5 else 1.0)
	kick_roll += deg_to_rad(float(wd["kick_roll"])) * randf_range(-1.0, 1.0)
	flash.visible = true
	flash.rotation.z = randf() * TAU
	flash_t = 0.045
	if wd["interval"] > 1.0 or wid == "m1014":
		cycle_p = 0.0
		cycle_len = maxf(wd["interval"] * 0.85, 0.3)


func start_reload(dur: float) -> void:
	reload_p = 0.0
	reload_len = dur


func cancel_reload() -> void:
	reload_p = -1.0


# --------------------------------------------------------------------------
func step(delta: float, move_ratio: float, on_floor: bool, look_delta: Vector2, crouched: bool, sliding: bool) -> void:
	if weapon == null or sk == null or _fingers["R"].is_empty():
		return
	equip_p = minf(equip_p + delta * 3.2, 1.0)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			flash.visible = false
	kick_pos = lerpf(kick_pos, 0.0, clampf(delta * 14.0, 0, 1))
	kick_pitch = lerpf(kick_pitch, 0.0, clampf(delta * 10.0, 0, 1))
	kick_roll = lerpf(kick_roll, 0.0, clampf(delta * 9.0, 0, 1))
	if reload_p >= 0.0:
		reload_p += delta / reload_len
		if reload_p >= 1.0:
			reload_p = -1.0
	if cycle_p >= 0.0:
		cycle_p += delta / cycle_len
		if cycle_p >= 1.0:
			cycle_p = -1.0
	# تمايل (يتأخر عن حركة الكاميرا)
	_lookd = _lookd.lerp(look_delta, clampf(delta * 20.0, 0, 1))
	_sway = _sway.lerp(Vector2(-_lookd.x, -_lookd.y) * 0.0009, clampf(delta * 8.0, 0, 1))
	_sway = _sway.clamp(Vector2(-0.05, -0.05), Vector2(0.05, 0.05))
	# اهتزاز المشي
	var amp := move_ratio if on_floor else 0.0
	_bob_amp = lerpf(_bob_amp, amp, clampf(delta * 8.0, 0, 1))
	_bob_t += delta * (6.0 + 5.0 * move_ratio)
	sprint = lerpf(sprint, 1.0 if move_ratio > 0.85 and ads < 0.1 and not crouched else 0.0, clampf(delta * 8.0, 0, 1))
	if sliding:
		sprint = lerpf(sprint, 0.5, clampf(delta * 8.0, 0, 1))

	var a := smoothstep(0.0, 1.0, ads)
	var sight: Vector2 = wd["sight"]
	var hip: Vector3 = Vector3(0.165, -0.215, -0.40) - (wd["rgrip"] as Vector3)
	var adsp: Vector3 = Vector3(0.0, -(sight.y + (0.0 if bool(wd["scope"]) else 0.03)), -0.34 - sight.x)
	var pos: Vector3 = hip.lerp(adsp, a)
	var bob := Vector3(cos(_bob_t * 0.5) * 0.008, absf(sin(_bob_t * 0.5)) * 0.012, 0.0) * _bob_amp * (1.0 - a * 0.85)
	var idle := Vector3(0, sin(Time.get_ticks_msec() * 0.0017) * 0.0015, 0)
	pos += bob + idle
	pos.z += kick_pos
	pos += Vector3(_sway.x, _sway.y, 0.0) * (1.0 - a * 0.7)
	# ركض: السلاح ينخفض ويميل
	pos += Vector3(0.03, -0.08, 0.02) * sprint
	# قرب الجدار: يرجع السلاح للخلف ويرتفع
	pos += Vector3(0.0, 0.0, 0.32) * wall + Vector3(0.0, -0.04, 0.0) * wall
	# رفع السلاح عند تبديله
	var eq := 1.0 - equip_p
	pos += Vector3(0.0, -0.35, 0.1) * eq
	var rot_pitch := kick_pitch + deg_to_rad(-18.0) * sprint + deg_to_rad(55.0) * wall + deg_to_rad(-40.0) * eq
	var rot_yaw := deg_to_rad(5.0) * (1.0 - a) + deg_to_rad(12.0) * sprint + _sway.x * 1.2 + deg_to_rad(-30.0) * wall
	var rot_roll := kick_roll * 0.5 + deg_to_rad(-6.0) * sprint + _sway.x * 0.6
	var rp := -1.0

	# إعادة التعبئة
	var lg: Vector3 = wd["lgrip"]
	var rg: Vector3 = wd["rgrip"]
	var l_extra := Vector3.ZERO
	if reload_p >= 0.0:
		rp = reload_p
		var tilt := _bell(rp, 0.08, 0.2, 0.82, 0.96)
		rot_pitch += deg_to_rad(-12.0) * tilt
		rot_roll += deg_to_rad(-26.0) * tilt
		rot_yaw += deg_to_rad(14.0) * tilt
		pos += Vector3(-0.03, -0.05, 0.05) * tilt
		var mag: Vector3 = wd["mag_pos"]
		var to_mag := _bell(rp, 0.1, 0.24, 0.62, 0.76)       # اليد تذهب للمخزن
		var away := _bell(rp, 0.3, 0.46, 0.5, 0.62)          # المخزن يخرج
		lg = lg.lerp(mag + Vector3(0.0, 0.0, 0.0), to_mag)
		l_extra = Vector3(-0.05, -0.12, 0.05) * away
		if wid == "awm":
			rg = rg.lerp(Vector3(0.05, 0.07, 0.07), _bell(rp, 0.05, 0.15, 0.85, 0.95))
	if cycle_p >= 0.0:
		var sw := sin(cycle_p * PI)
		if wid == "awm":
			rg = rg.lerp(Vector3(0.05, 0.065, 0.065 + 0.11 * sw), _bell(cycle_p, 0.0, 0.2, 0.8, 1.0))
			rot_roll += deg_to_rad(-10.0) * sw
		elif wid == "m1014":
			lg += Vector3(0.0, 0.0, 0.1 * sw)

	weapon.position = pos
	weapon.rotation = Vector3(rot_pitch, rot_yaw, rot_roll)
	weapon.visible = not hide_weapon
	_pose_hands(rg, lg, l_extra, ads, rp)


func _bell(t: float, a: float, b: float, c: float, d: float) -> float:
	if t < a or t > d:
		return 0.0
	if t < b:
		return smoothstep(a, b, t)
	if t <= c:
		return 1.0
	return 1.0 - smoothstep(c, d, t)


# مواضع اليدين بالنسبة للسلاح (محليًا) + اتجاه الكف
var hand_cfg := {
	"R": {"f": Vector3(-0.30, -0.62, -0.72), "t": Vector3(0.15, 0.85, -0.50), "curl": 1.05},
	"L": {"f": Vector3(0.05, 0.12, -1.0), "t": Vector3(-0.90, 0.40, 0.0), "curl": 0.95},
}


func _pose_hands(rg: Vector3, lg: Vector3, l_extra: Vector3, ads_v: float, rp: float) -> void:
	sk.reset_bone_poses()
	var wb := weapon.transform.basis
	var to_sk := sk.global_transform.affine_inverse() * global_transform
	var fr: Vector3 = wb * (hand_cfg["R"]["f"] as Vector3).normalized()
	var fl: Vector3 = wb * (hand_cfg["L"]["f"] as Vector3).normalized()
	var tr_r := to_sk * (weapon.transform * rg - fr * PALM_BACK)
	var tr_l := to_sk * (weapon.transform * lg + l_extra - fl * PALM_BACK)
	_solve_side("R", tr_r, wb, to_sk.basis)
	_solve_side("L", tr_l, wb, to_sk.basis)


func _solve_side(side: String, target_sk: Vector3, wb: Basis, bsk: Basis) -> void:
	var b: Dictionary = _bones[side]
	var pole_v := Vector3(0.45 if side == "R" else -0.45, -1.0, 0.25)
	var pole_sk := (bsk * pole_v).normalized()
	IK.solve(sk, b["upper"], b["fore"], b["wrist"], target_sk, pole_sk)
	# اتجاه اليد
	var cfg: Dictionary = hand_cfg[side]
	var f_view: Vector3 = wb * (cfg["f"] as Vector3).normalized()
	var t_view: Vector3 = wb * (cfg["t"] as Vector3).normalized()
	var want := IK.frame(bsk * f_view, bsk * t_view)
	var rot: Basis = want * (_rest_frame[side] as Basis).inverse()
	var hroot: int = b["hroot"]
	var rest_basis: Basis = _rest_hand_cache[hroot]
	IK.set_global(sk, hroot, Transform3D(rot * rest_basis, target_sk))
	# ثني الأصابع
	var curl: float = cfg["curl"]
	var sign_v := 1.0 if side == "R" else -1.0
	for fd in _fingers[side]:
		var idx: int = fd["i"]
		var amount := curl * (0.55 if fd["j"] == 1 else (1.0 if fd["j"] == 2 else 0.8))
		if fd["n"] == "index":
			amount *= 0.7
		var rb: Basis = _rest_global[idx]
		var axis_local := (rb.inverse() * (_rest_t[side] as Vector3)).normalized()
		var q := sk.get_bone_pose_rotation(idx)
		sk.set_bone_pose_rotation(idx, q * Quaternion(axis_local, amount * sign_v))



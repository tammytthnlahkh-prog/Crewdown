class_name CharModel
extends Node3D
## نموذج الشخصية للاعبين الآخرين (مومياء/فتاة) + سلاح بيدهم.

const HEIGHT := 1.78

var kind: String = "mummy"
var root: Node3D
var sk: Skeleton3D
var weapon: Node3D
var wid: String = ""
var flash: MeshInstance3D
var flash_t: float = 0.0
var _t: float = 0.0
var _phase: float = 0.0
var _bones := {}
var _rest_q := {}
var _rest_gb := {}
var dead: bool = false
var _fall: float = 0.0
var crouch_amt: float = 0.0


func build(character: String) -> void:
	kind = character
	var path := "res://models/chars/%s/scene.gltf" % ("girl" if character == "girl" else "mummy")
	root = Node3D.new()
	add_child(root)
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	root.add_child(inst)
	if character != "girl":
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			# المستوى الأرضي الضخم (14×14) يجب إخفاؤه
			# (لا نعتمد على global_transform لأنه قد يكون غير محدّث لحظة الإنشاء؛
			#  المستوى الأرضي مسطّح تمامًا بينما المومياء ارتفاعها كبير)
			var la: AABB = mi.get_aabb()
			if la.size.y < 0.01 or mi.get_parent().name.begins_with("Plane"):
				mi.visible = false
				mi.queue_free()
	if character != "girl":
		# المومياء مجسّم ثابت بلا هيكل عظمي: نثني الذراعين فيزيائيًا في الشبكة
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi3 := m as MeshInstance3D
			if mi3.is_queued_for_deletion():
				continue
			if mi3.name == "Object_4" or mi3.name == "Object_6":
				_bend_arms(mi3)
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi2 := m as MeshInstance3D
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi2.extra_cull_margin = 2.0
	var s := HEIGHT / (1.81 if character != "girl" else 1.82)
	inst.scale = Vector3.ONE * s
	# الموديلات تنظر نحو +Z → ندور 180° ليصبح الأمام -Z
	root.rotation_degrees.y = 180.0
	if character == "girl":
		var sks := inst.find_children("*", "Skeleton3D", true, false)
		if sks.size() > 0:
			sk = sks[0]
			for k in ["RightArm", "RightForeArm", "RightHand", "LeftArm", "LeftForeArm", "LeftHand", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "Spine"]:
				var avoid := PackedStringArray()
				if k == "RightArm" or k == "LeftArm":
					avoid = PackedStringArray(["ForeArm", "Shoulder"])
				if k == "RightHand" or k == "LeftHand":
					avoid = PackedStringArray(["Thumb", "Index", "Middle", "Ring", "Pinky"])
				if k == "RightLeg" or k == "LeftLeg":
					avoid = PackedStringArray(["UpLeg"])
				if k == "Spine":
					avoid = PackedStringArray(["Spine1", "Spine2"])
				_bones[k] = IK.find_bone(sk, k, avoid)
			sk.reset_bone_poses()
			for k in ["LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"]:
				var i: int = _bones[k]
				if i >= 0:
					_rest_q[k] = sk.get_bone_pose_rotation(i)
					_rest_gb[k] = sk.get_bone_global_pose(i).basis


func set_weapon(id: String) -> void:
	if wid == id and weapon:
		return
	wid = id
	if weapon:
		weapon.queue_free()
	weapon = WeaponModel.make(id)
	add_child(weapon)
	var wd: Dictionary = WDB.DATA[id]
	flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	flash.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ViewModel._flash_tex()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash.material_override = m
	flash.position = (wd["muzzle"] as Vector3) + Vector3(0, 0, -0.05)
	flash.visible = false
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon.add_child(flash)
	weapon.visible = not dead


func muzzle_world() -> Vector3:
	if weapon == null:
		return global_position + Vector3(0, 1.4, 0)
	return weapon.global_transform * (WDB.DATA[wid]["muzzle"] as Vector3)


func shot_flash() -> void:
	if flash:
		flash.visible = true
		flash.rotation.z = randf() * TAU
		flash_t = 0.05


func die() -> void:
	dead = true
	if weapon:
		weapon.visible = false


func revive() -> void:
	dead = false
	_fall = 0.0
	root.rotation.x = 0.0
	root.position = Vector3.ZERO
	if weapon:
		weapon.visible = true


func pose(delta: float, speed: float, aim_pitch: float, crouched: bool, on_floor: bool, sliding: bool) -> void:
	_t += delta
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0 and flash:
			flash.visible = false
	crouch_amt = lerpf(crouch_amt, 1.0 if (crouched or sliding) else 0.0, clampf(delta * 10.0, 0, 1))
	if dead:
		_fall = minf(_fall + delta * 2.5, 1.0)
		root.rotation.x = lerpf(0.0, deg_to_rad(-82.0), smoothstep(0.0, 1.0, _fall))
		root.position.y = 0.0
		root.position.z = lerpf(0.0, 0.4, _fall)
		return
	var moving := clampf(speed / 5.0, 0.0, 1.4)
	if not on_floor:
		moving *= 0.3
	_phase += delta * (4.0 + 6.0 * moving) * (1.0 if moving > 0.05 else 0.0)
	# مومياء: اهتزاز وميلان؛ فتاة: ساقان تتحركان
	var bob := absf(sin(_phase)) * 0.05 * moving
	root.position = Vector3(0, bob - 0.55 * crouch_amt * (1.0 if kind != "girl" else 0.0), 0)
	if kind == "mummy":
		root.rotation.x = deg_to_rad(-6.0) * moving + deg_to_rad(-25.0) * crouch_amt
		root.rotation.z = sin(_phase) * 0.05 * moving
		root.scale = Vector3(1.0, 1.0 - 0.28 * crouch_amt, 1.0)
	else:
		root.rotation.x = deg_to_rad(-25.0) * crouch_amt * 0.0
		root.scale = Vector3(1.0, 1.0 - 0.28 * crouch_amt, 1.0)
		_legs(moving)
	# السلاح أمام الصدر
	if weapon:
		var h := 1.28 - 0.4 * crouch_amt
		weapon.position = Vector3(0.17, h, -0.28)
		weapon.rotation = Vector3(aim_pitch, 0.0, 0.0)
		# يتحرك السلاح مع نظر اللاعب حول محور الكتف
		var pivot := Vector3(0.0, h + 0.2, 0.0)
		var rel := weapon.position - pivot
		rel = rel.rotated(Vector3.RIGHT, aim_pitch)
		weapon.position = pivot + rel
		if sk:
			_arms()


func _legs(moving: float) -> void:
	if sk == null:
		return
	sk.reset_bone_poses()
	var axis_sk := (sk.global_transform.basis.inverse() * (global_transform.basis * Vector3.RIGHT)).normalized()
	var a := sin(_phase) * 0.7 * moving
	var side_i := 0
	for s in ["Left", "Right"]:
		var dir := 1.0 if s == "Left" else -1.0
		var up_i: int = _bones[s + "UpLeg"]
		var kn_i: int = _bones[s + "Leg"]
		if up_i < 0 or kn_i < 0:
			continue
		var ang := a * dir - 0.55 * crouch_amt
		var axl := ((_rest_gb[s + "UpLeg"] as Basis).inverse() * axis_sk).normalized()
		sk.set_bone_pose_rotation(up_i, (_rest_q[s + "UpLeg"] as Quaternion) * Quaternion(axl, ang))
		var kang := maxf(0.0, -ang) * 1.2 + 1.0 * crouch_amt
		var axk := ((_rest_gb[s + "Leg"] as Basis).inverse() * axis_sk).normalized()
		sk.set_bone_pose_rotation(kn_i, (_rest_q[s + "Leg"] as Quaternion) * Quaternion(axk, -kang))
		side_i += 1


func _arms() -> void:
	if _bones.get("RightArm", -1) < 0 or _bones.get("LeftArm", -1) < 0:
		return
	var wd: Dictionary = WDB.DATA[wid]
	var to_sk := sk.global_transform.affine_inverse()
	var tr: Vector3 = to_sk * (weapon.global_transform * (wd["rgrip"] as Vector3))
	var tl: Vector3 = to_sk * (weapon.global_transform * (wd["lgrip"] as Vector3))
	var bs := to_sk.basis * global_transform.basis
	IK.solve(sk, _bones["RightArm"], _bones["RightForeArm"], _bones["RightHand"], tr, (bs * Vector3(0.5, -1.0, 0.1)).normalized())
	IK.solve(sk, _bones["LeftArm"], _bones["LeftForeArm"], _bones["LeftHand"], tl, (bs * Vector3(-0.5, -1.0, 0.1)).normalized())


# ------------------------------------------------------------------ ثني ذراعي المومياء
# إحداثيات الشبكة بالسنتيمتر (Y لأعلى، الوجه نحو +Z، الذراعان على ±X بوضعية A).
# عند الدوران 180° حول Y يصبح ذراع x<0 هو اليمنى (تحمل المسدس) وذراع x>0 هي اليسرى.
const _ARM_S := Vector3(22, 140, 0)
const _ARM_E := Vector3(37, 121, -1)
const _ARM_H := Vector3(47, 98, -14)
const _TARGET_R := Vector3(-17.0, 123.0, 9.0)     # قبضة السلاح (اليمنى)
const _TARGET_L := Vector3(-14.0, 128.0, 36.0)    # المقدمة (اليسرى)


static func _solve_arm(sgn: float, target: Vector3) -> Dictionary:
	var S := Vector3(_ARM_S.x * sgn, _ARM_S.y, _ARM_S.z)
	var E0 := Vector3(_ARM_E.x * sgn, _ARM_E.y, _ARM_E.z)
	var H0 := Vector3(_ARM_H.x * sgn, _ARM_H.y, _ARM_H.z)
	var l1 := (E0 - S).length()
	var l2 := (H0 - E0).length()
	var to_t := target - S
	var d := clampf(to_t.length(), absf(l1 - l2) + 0.5, l1 + l2 - 0.5)
	var dir := to_t.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pole := Vector3(sgn * 0.6, -1.0, -0.2)
	var perp := (pole - dir * pole.dot(dir)).normalized()
	var E := S + dir * a + perp * h
	var H := S + dir * d
	var r1 := Quaternion((E0 - S).normalized(), (E - S).normalized())
	var f0 := r1 * (H0 - E0)
	var r2 := Quaternion(f0.normalized(), (H - E).normalized())
	return {"S": S, "E0": E0, "E": E, "r1": r1, "r12": r2 * r1}


func _bend_arms(mi: MeshInstance3D) -> void:
	var left_arm := _solve_arm(1.0, _TARGET_L)     # x>0 → اليسرى بعد الدوران
	var right_arm := _solve_arm(-1.0, _TARGET_R)   # x<0 → اليمنى
	var old: ArrayMesh = mi.mesh as ArrayMesh
	if old == null:
		return
	var nm := ArrayMesh.new()
	for si in old.get_surface_count():
		var arr: Array = old.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for i in vs.size():
			var v := vs[i]
			var ax := absf(v.x)
			if v.y < 85.0 or ax < 21.0:
				continue
			var wu := smoothstep(21.0, 31.0, ax)
			var we := smoothstep(33.0, 41.0, ax)
			var A: Dictionary = left_arm if v.x > 0.0 else right_arm
			var S: Vector3 = A["S"]
			var E0: Vector3 = A["E0"]
			var E1: Vector3 = A["E"]
			var q1: Quaternion = A["r1"]
			var q12: Quaternion = A["r12"]
			var v_up := S + q1 * (v - S)
			var v_fo := E1 + q12 * (v - E0)
			vs[i] = v.lerp(v_up.lerp(v_fo, we), wu)
			if ns.size() == vs.size():
				var n_up := q1 * ns[i]
				var n_fo := q12 * ns[i]
				ns[i] = ns[i].lerp(n_up.lerp(n_fo, we), wu).normalized()
		arr[Mesh.ARRAY_VERTEX] = vs
		if ns.size() == vs.size():
			arr[Mesh.ARRAY_NORMAL] = ns
		arr[Mesh.ARRAY_TANGENT] = null
		nm.add_surface_from_arrays(old.surface_get_primitive_type(si), arr)
		nm.surface_set_material(si, old.surface_get_material(si))
	mi.mesh = nm

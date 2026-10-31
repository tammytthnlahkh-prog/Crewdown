class_name IK
## حلّ IK لذراع بعظمتين + أدوات لضبط عظام الهيكل (فضاء الهيكل Skeleton).


static func set_global(sk: Skeleton3D, bone: int, xf: Transform3D) -> void:
	var p := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(p) if p >= 0 else Transform3D()
	var l := pg.affine_inverse() * xf
	sk.set_bone_pose_position(bone, l.origin)
	sk.set_bone_pose_rotation(bone, l.basis.orthonormalized().get_rotation_quaternion())


static func aim(sk: Skeleton3D, bone: int, child: int, goal: Vector3) -> void:
	var g := sk.get_bone_global_pose(bone)
	var cur := sk.get_bone_global_pose(child).origin - g.origin
	var want := goal - g.origin
	if cur.length() < 0.00001 or want.length() < 0.00001:
		return
	var q := Quaternion(cur.normalized(), want.normalized())
	set_global(sk, bone, Transform3D(Basis(q) * g.basis, g.origin))


## upper → fore → wrist. الهدف ومتجه المرفق بفضاء الهيكل.
static func solve(sk: Skeleton3D, upper: int, fore: int, wrist: int, target: Vector3, pole: Vector3) -> void:
	var a := sk.get_bone_global_pose(upper).origin
	var b := sk.get_bone_global_pose(fore).origin
	var c := sk.get_bone_global_pose(wrist).origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var to_t := target - a
	var dist := clampf(to_t.length(), absf(l1 - l2) + 0.0005, l1 + l2 - 0.0005)
	var u := to_t.normalized()
	var k := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - k * k, 0.0))
	var perp := pole - u * pole.dot(u)
	if perp.length() < 0.001:
		perp = u.cross(Vector3.UP)
	perp = perp.normalized()
	var e := a + u * k + perp * h
	var t := a + u * dist
	aim(sk, upper, fore, e)
	aim(sk, fore, wrist, t)


static func frame(f: Vector3, t: Vector3) -> Basis:
	var fz := f.normalized()
	var tx := (t - fz * t.dot(fz)).normalized()
	var py := fz.cross(tx)
	return Basis(tx, py, fz)


static func find_bone(sk: Skeleton3D, key: String, avoid: PackedStringArray = PackedStringArray()) -> int:
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.contains(key):
			var bad := false
			for a in avoid:
				if n.contains(a):
					bad = true
			if not bad:
				return i
	return -1

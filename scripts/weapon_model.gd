class_name WeaponModel
## يبني نموذج سلاح مُطبَّع: الفوهة نحو -Z، المركز عند مركز الصندوق، الطول حسب الجدول.

static var _cache: Dictionary = {}


static func _bounds(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var bb: AABB = t * (n as MeshInstance3D).get_aabb()
		if acc[0] == null:
			acc[0] = bb
		else:
			acc[0] = (acc[0] as AABB).merge(bb)
	for c in n.get_children():
		_bounds(c, t, acc)


static func make(id: String) -> Node3D:
	var wd: Dictionary = WDB.DATA[id]
	var root := Node3D.new()
	root.name = "W_" + id
	var inner := Node3D.new()
	root.add_child(inner)
	var hold := Node3D.new()
	inner.add_child(hold)
	var scene: Node3D = (load(wd["model"]) as PackedScene).instantiate()
	hold.add_child(scene)
	hold.rotation_degrees.y = wd["yaw"]
	var acc := [null]
	_bounds(hold, Transform3D(), acc)
	var bb: AABB = acc[0]
	var s: float = float(wd["len"]) / bb.size.z
	inner.scale = Vector3.ONE * s
	var c := bb.get_center() * s
	inner.position = -c
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

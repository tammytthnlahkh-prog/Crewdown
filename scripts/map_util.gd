class_name MapUtil
## يرفع جدران الخريطة (الشبكات الكبيرة والعالية فقط) ويبقي الأرضيات والأثاث بحجمها.

const WALL_K := 2.2


static func raise_walls(map: Node3D, k: float = WALL_K) -> void:
	for m in map.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if maxf(bb.size.x, bb.size.z) > 12.0 and bb.size.y > 0.8:
			mi.global_transform = Transform3D(Basis.from_scale(Vector3(1.0, k, 1.0)), Vector3.ZERO) * mi.global_transform

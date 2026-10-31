class_name WDB
## بيانات الأسلحة (قيم مقاربة لببجي موبايل). الاتجاهات: -Z للأمام، +Y للأعلى، +X لليمين (إحداثيات السلاح).

const ORDER := ["akm", "m4", "awm", "m1014"]

const DATA := {
	"akm": {
		"name": "AKM", "model": "res://models/weapons/akm/scene.gltf", "yaw": 0.0, "len": 0.88,
		"dmg": 47.0, "head": 2.0, "interval": 0.100, "auto": true, "mag": 30,
		"reload": 2.9, "reload_empty": 3.7, "pellets": 1, "range": 160.0,
		"spread_hip": 2.3, "spread_ads": 0.25, "spread_move": 1.8, "spread_air": 3.5,
		"rec_pitch": 0.95, "rec_yaw": 0.38, "rec_ramp": 0.07, "rec_recover": 9.0, "rec_ads": 0.62,
		"kick_back": 0.035, "kick_roll": 1.3,
		"ads_fov": 50.0, "scope": false, "sight": Vector2(0.08, 0.118),
		"rgrip": Vector3(0.0, -0.075, 0.19), "lgrip": Vector3(0.0, -0.012, -0.10),
		"mag_pos": Vector3(0.0, -0.20, -0.03), "muzzle": Vector3(0.0, 0.075, -0.44), "eject": Vector3(0.025, 0.075, 0.03),
		"speed": 0.94, "sfx": "shot_akm", "pitch": 1.0, "mag_sound": true,
	},
	"m4": {
		"name": "M4", "model": "res://models/weapons/m4/scene.gltf", "yaw": -90.0, "len": 0.85,
		"dmg": 41.0, "head": 2.0, "interval": 0.0857, "auto": true, "mag": 30,
		"reload": 2.1, "reload_empty": 2.9, "pellets": 1, "range": 170.0,
		"spread_hip": 2.0, "spread_ads": 0.2, "spread_move": 1.6, "spread_air": 3.2,
		"rec_pitch": 0.62, "rec_yaw": 0.24, "rec_ramp": 0.05, "rec_recover": 11.0, "rec_ads": 0.6,
		"kick_back": 0.028, "kick_roll": 1.0,
		"ads_fov": 50.0, "scope": false, "sight": Vector2(0.10, 0.122),
		"rgrip": Vector3(0.0, -0.08, 0.176), "lgrip": Vector3(0.0, -0.005, -0.12),
		"mag_pos": Vector3(0.0, -0.18, -0.02), "muzzle": Vector3(0.0, 0.07, -0.43), "eject": Vector3(0.025, 0.06, 0.04),
		"speed": 1.0, "sfx": "shot_m4", "pitch": 1.0, "mag_sound": true,
	},
	"awm": {
		"name": "AWM", "model": "res://models/weapons/awm/scene.gltf", "yaw": 90.0, "len": 1.25,
		"dmg": 120.0, "head": 2.6, "interval": 1.85, "auto": false, "mag": 5,
		"reload": 4.6, "reload_empty": 4.6, "pellets": 1, "range": 400.0,
		"spread_hip": 3.5, "spread_ads": 0.0, "spread_move": 3.0, "spread_air": 5.0,
		"rec_pitch": 4.2, "rec_yaw": 0.6, "rec_ramp": 0.0, "rec_recover": 6.0, "rec_ads": 0.7,
		"kick_back": 0.09, "kick_roll": 3.0,
		"ads_fov": 13.0, "scope": true, "sight": Vector2(0.20, 0.09),
		"rgrip": Vector3(0.0, -0.07, 0.22), "lgrip": Vector3(0.0, -0.035, 0.0),
		"mag_pos": Vector3(0.0, -0.12, 0.08), "muzzle": Vector3(0.0, 0.035, -0.64), "eject": Vector3(0.03, 0.05, 0.10),
		"speed": 0.88, "sfx": "shot_awm", "pitch": 1.0, "mag_sound": true,
	},
	"m1014": {
		"name": "M1014", "model": "res://models/weapons/m1014/scene.gltf", "yaw": -90.0, "len": 0.95,
		"dmg": 12.0, "head": 1.6, "interval": 0.24, "auto": false, "mag": 8,
		"reload": 3.9, "reload_empty": 3.9, "pellets": 9, "range": 55.0,
		"spread_hip": 3.2, "spread_ads": 2.4, "spread_move": 3.8, "spread_air": 5.0,
		"rec_pitch": 3.0, "rec_yaw": 0.5, "rec_ramp": 0.0, "rec_recover": 8.0, "rec_ads": 0.7,
		"kick_back": 0.07, "kick_roll": 2.2,
		"ads_fov": 54.0, "scope": false, "sight": Vector2(0.06, 0.07),
		"rgrip": Vector3(0.0, -0.065, 0.19), "lgrip": Vector3(0.0, 0.005, -0.12),
		"mag_pos": Vector3(0.0, -0.10, 0.02), "muzzle": Vector3(0.0, 0.04, -0.48), "eject": Vector3(0.025, 0.045, 0.03),
		"speed": 0.96, "sfx": "shot_m1014", "pitch": 1.0, "mag_sound": false,
	},
}


static func get_w(id: String) -> Dictionary:
	return DATA[id]

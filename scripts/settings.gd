extends Node
## الإعدادات المحفوظة: الاسم، الشخصية، الحساسية، الجيروسكوب، ترتيب أزرار اللمس.

const PATH := "user://crewdown.cfg"

var player_name: String = "لاعب"
var character: String = "mummy"        # mummy | girl
var look_sens: float = 0.25            # درجة لكل بكسل (لمس)
var ads_mult: float = 0.55             # معامل حساسية التصويب
var scope_mult: float = 0.35           # معامل حساسية السكوب (AWM)
var gyro_on: bool = false
var gyro_sens: float = 1.0
var invert_y: bool = false
var master_vol: float = 0.9
var last_ip: String = ""
var fov: float = 66.0
var fire_mode_hold: bool = true        # زر النار: اضغط مطولًا
var layout: Dictionary = {}            # id -> {x, y, s, a}  (x,y نسبة من الشاشة 0..1)

# الترتيب الافتراضي (نسب من عرض/ارتفاع الشاشة، مركز الزر)
const DEFAULT_LAYOUT := {
	"joystick": {"x": 0.14, "y": 0.72, "s": 1.0, "a": 0.55},
	"fire":     {"x": 0.88, "y": 0.66, "s": 1.0, "a": 0.6},
	"fire2":    {"x": 0.10, "y": 0.40, "s": 0.8, "a": 0.5},
	"ads":      {"x": 0.78, "y": 0.80, "s": 0.9, "a": 0.6},
	"jump":     {"x": 0.93, "y": 0.84, "s": 0.9, "a": 0.6},
	"crouch":   {"x": 0.68, "y": 0.87, "s": 0.8, "a": 0.6},
	"reload":   {"x": 0.80, "y": 0.45, "s": 0.8, "a": 0.6},
	"score":    {"x": 0.62, "y": 0.09, "s": 0.7, "a": 0.5},
}


func _ready() -> void:
	load_all()
	apply_volume()


func get_btn(id: String) -> Dictionary:
	var d: Dictionary = DEFAULT_LAYOUT[id].duplicate()
	if layout.has(id):
		for k in layout[id]:
			d[k] = layout[id][k]
	return d


func set_btn(id: String, x: float, y: float, s: float, a: float) -> void:
	layout[id] = {"x": x, "y": y, "s": s, "a": a}


func reset_layout() -> void:
	layout = {}
	save_all()


func apply_volume() -> void:
	var db := linear_to_db(clampf(master_vol, 0.001, 1.0))
	AudioServer.set_bus_volume_db(0, db)


func save_all() -> void:
	var c := ConfigFile.new()
	c.set_value("p", "name", player_name)
	c.set_value("p", "character", character)
	c.set_value("p", "look_sens", look_sens)
	c.set_value("p", "ads_mult", ads_mult)
	c.set_value("p", "scope_mult", scope_mult)
	c.set_value("p", "gyro_on", gyro_on)
	c.set_value("p", "gyro_sens", gyro_sens)
	c.set_value("p", "invert_y", invert_y)
	c.set_value("p", "master_vol", master_vol)
	c.set_value("p", "last_ip", last_ip)
	c.set_value("p", "fov", fov)
	c.set_value("p", "layout", layout)
	c.save(PATH)


func load_all() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	player_name = c.get_value("p", "name", player_name)
	character = "mummy"
	look_sens = c.get_value("p", "look_sens", look_sens)
	ads_mult = c.get_value("p", "ads_mult", ads_mult)
	scope_mult = c.get_value("p", "scope_mult", scope_mult)
	gyro_on = c.get_value("p", "gyro_on", gyro_on)
	gyro_sens = c.get_value("p", "gyro_sens", gyro_sens)
	invert_y = c.get_value("p", "invert_y", invert_y)
	master_vol = c.get_value("p", "master_vol", master_vol)
	last_ip = c.get_value("p", "last_ip", last_ip)
	fov = c.get_value("p", "fov", fov)
	layout = c.get_value("p", "layout", {})

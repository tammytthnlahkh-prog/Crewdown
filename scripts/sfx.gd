extends Node
## مشغّل الأصوات: 2D و 3D مع تجميع مشغّلات.

var _streams: Dictionary = {}
var _pool2d: Array = []
var _pool3d: Array = []


func _ready() -> void:
	var d := DirAccess.open("res://audio")
	if d:
		for f in d.get_files():
			var n := f.get_basename()
			if f.ends_with(".wav") or f.ends_with(".wav.import"):
				var key := f.replace(".import", "").get_basename()
				if not _streams.has(key):
					_streams[key] = load("res://audio/" + f.replace(".import", ""))
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)
	for i in 14:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 6.0
		p3.max_distance = 70.0
		add_child(p3)
		_pool3d.append(p3)


func play(name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	for p in _pool2d:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return


func play3d(name: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	for p in _pool3d:
		if not p.playing:
			p.stream = _streams[name]
			p.global_position = pos
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return

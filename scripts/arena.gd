extends Node3D
## الحلبة: الخريطة، اللاعبون، القتال (المضيف هو الحَكَم)، الإحياء، دوائر العلاج، الوقت.

const MAP_SCALE := 7.0
const HEAL_RADIUS := 1.7
const RESPAWN_DELAY := 3.0

var players: Dictionary = {}     # id -> Player
var local: Player
var hud: HUD
var frozen: bool = true
var ended: bool = false
var spawns: Array = []
var heals: Array = []
var _heal_nodes: Array = []
var _heal_tick: float = 0.0
var _time_sync: float = 0.0
var _respawn_q: Dictionary = {}   # id -> seconds
var _last_shot: Dictionary = {}
var _hp_host: Dictionary = {}     # id -> {choosing, invuln, alive}
var _death_t: float = 0.0
var _death_active: bool = false
var _last_wid: String = "m4"
var _last_killer: String = ""


func _ready() -> void:
	name = "Arena"
	_build_world()
	hud = HUD.new()
	hud.arena = self
	add_child(hud)
	hud.weapon_chosen.connect(_on_weapon_chosen)
	hud.leave_pressed.connect(_leave)
	hud.rematch_pressed.connect(func() -> void: Net.start_match())
	Net.roster_changed.connect(_sync_players)
	Net.left_room.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	_sync_players()
	if Net.is_host:
		Net.time_left = Net.MATCH_SECONDS
		for id in players:
			_host_respawn(id, true)
	hud.toast("استعد!", 2.0)
	frozen = false


func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.86, 0.95)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.55
	sun.shadow_enabled = false
	add_child(sun)
	var map: Node3D = (load("res://models/map/scene.gltf") as PackedScene).instantiate()
	map.scale = Vector3.ONE * MAP_SCALE
	add_child(map)
	MapUtil.raise_walls(map)
	for m in map.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 0.0
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = load("res://data/map_collision.res")
	body.add_child(cs)
	add_child(body)
	var f := FileAccess.open("res://data/map_data.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for s in d["spawns"]:
		spawns.append(Vector3(s[0], s[1], s[2]))
	for h in d["heals"]:
		heals.append(Vector3(h[0], h[1], h[2]))
	for h in heals:
		_make_heal(h)


func _make_heal(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = HEAL_RADIUS
	cm.bottom_radius = HEAL_RADIUS
	cm.height = 2.4
	cm.radial_segments = 28
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	cyl.mesh = cm
	cyl.position.y = 1.2
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/heal.gdshader")
	cyl.material_override = mat
	cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(cyl)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = HEAL_RADIUS
	dm.bottom_radius = HEAL_RADIUS
	dm.height = 0.02
	dm.radial_segments = 28
	dm.rings = 1
	disc.mesh = dm
	disc.position.y = 0.04
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.albedo_color = Color(0.1, 1.0, 0.35, 0.5)
	m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	disc.material_override = m2
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(disc)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = HEAL_RADIUS - 0.08
	tm.outer_radius = HEAL_RADIUS
	tm.rings = 32
	tm.ring_segments = 6
	ring.mesh = tm
	ring.position.y = 0.06
	var m3 := StandardMaterial3D.new()
	m3.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m3.albedo_color = Color(0.4, 1.0, 0.6)
	ring.material_override = m3
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	var pr := CPUParticles3D.new()
	pr.amount = 14
	pr.lifetime = 1.8
	pr.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pr.emission_sphere_radius = HEAL_RADIUS * 0.8
	pr.direction = Vector3.UP
	pr.spread = 5.0
	pr.initial_velocity_min = 0.5
	pr.initial_velocity_max = 1.0
	pr.gravity = Vector3.ZERO
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	var m4 := StandardMaterial3D.new()
	m4.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m4.albedo_color = Color(0.5, 1.0, 0.6)
	m4.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = m4
	pr.mesh = qm
	n.add_child(pr)
	_heal_nodes.append(n)


# ------------------------------------------------------------------ اللاعبون
func _sync_players() -> void:
	for id in Net.players:
		if not players.has(id):
			var p := Player.new()
			var info: Dictionary = Net.players[id]
			add_child(p)
			p.setup(id, info["name"], info["character"], self)
			players[id] = p
			_hp_host[id] = {"choosing": true, "invuln": 99.0, "alive": true}
			if p.is_local:
				local = p
				hud.bind(p)
				p.choosing = true
				p.teleport(spawns[0] if spawns.size() > 0 else Vector3.ZERO, 0.0)
				hud.show_choose(_last_wid)
			else:
				p.teleport(Vector3(0, -50, 0), 0.0)
				p.global_position = Vector3(0, -50, 0)
			if Net.is_host and not p.is_local and Net.in_match:
				_host_respawn(id, true)
	for id in players.keys():
		if not Net.players.has(id):
			players[id].queue_free()
			players.erase(id)


func peer_left(id: int) -> void:
	_hp_host.erase(id)
	_respawn_q.erase(id)


func request_unstuck() -> void:
	if Net.is_host:
		_host_respawn(Net.my_id(), false)
	else:
		_req_unstuck.rpc_id(1)


@rpc("any_peer", "reliable")
func _req_unstuck() -> void:
	if Net.is_host:
		_host_respawn(multiplayer.get_remote_sender_id(), false)


func _pick_spawn(for_id: int) -> Vector3:
	var best: Vector3 = spawns[0] if spawns.size() > 0 else Vector3.ZERO
	var bd := -1.0
	var cands: Array = spawns.duplicate()
	cands.shuffle()
	for s in cands.slice(0, 8):
		var md := 1e9
		for id in players:
			if id == for_id:
				continue
			var p: Player = players[id]
			if p.alive:
				md = minf(md, Vector2(p.global_position.x - s.x, p.global_position.z - s.z).length())
		md += randf() * 6.0
		if md > bd:
			bd = md
			best = s
	return best


func _host_respawn(id: int, first: bool) -> void:
	var pos := _pick_spawn(id)
	var yaw := randf() * TAU
	_hp_host[id] = {"choosing": true, "invuln": 99.0, "alive": true}
	_rpc_respawn.rpc(id, pos, yaw)


@rpc("authority", "call_local", "reliable")
func _rpc_respawn(id: int, pos: Vector3, yaw: float) -> void:
	if not players.has(id):
		return
	var p: Player = players[id]
	p.set_dead(false)
	p.hp = 100.0
	p.choosing = true
	p.teleport(pos, yaw)
	p.invuln = 99.0
	if p.is_local:
		hud.hide_death()
		_death_active = false
		hud.show_choose(_last_wid)
		Sfx.play("spawn", -3.0)
		p.vm.visible = true
	elif p.model:
		p.model.visible = true
		p.model.global_position = pos


func _on_weapon_chosen(id: String) -> void:
	_last_wid = id
	if Net.is_host:
		_host_chosen(Net.my_id(), id)
	else:
		_req_choose.rpc_id(1, id)


@rpc("any_peer", "reliable")
func _req_choose(id: String) -> void:
	if not Net.is_host:
		return
	_host_chosen(multiplayer.get_remote_sender_id(), id)


func _host_chosen(pid: int, w: String) -> void:
	if not WDB.DATA.has(w) or not _hp_host.has(pid):
		return
	_hp_host[pid]["choosing"] = false
	_hp_host[pid]["invuln"] = 2.5
	_rpc_equip.rpc(pid, w)


@rpc("authority", "call_local", "reliable")
func _rpc_equip(pid: int, w: String) -> void:
	if not players.has(pid):
		return
	var p: Player = players[pid]
	p.equip(w, true)
	p.choosing = false
	p.invuln = 2.5
	if p.is_local:
		Sfx.play("bolt", -2.0)
		hud.toast("بالتوفيق!", 1.2)


# ------------------------------------------------------------------ إطلاق النار
func local_shot(p: Player, origin: Vector3, dirs: PackedVector3Array, w: String) -> void:
	# أثر مرئي محلي فورًا
	var space := get_world_3d().direct_space_state
	var ends := PackedVector3Array()
	var rng: float = WDB.DATA[w]["range"]
	for d in dirs:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * rng, 3)
		q.exclude = [p.get_rid()]
		var h := space.intersect_ray(q)
		ends.append(h.position if not h.is_empty() else origin + d * rng)
	var muz := p.vm.weapon.global_transform * (WDB.DATA[w]["muzzle"] as Vector3)
	for e in ends:
		_tracer(muz, e)
		_impact(e)
	if Net.is_host:
		_server_shot(Net.my_id(), origin, dirs, w)
	else:
		_req_shot.rpc_id(1, origin, dirs, w)


@rpc("any_peer", "reliable")
func _req_shot(origin: Vector3, dirs: PackedVector3Array, w: String) -> void:
	if not Net.is_host:
		return
	_server_shot(multiplayer.get_remote_sender_id(), origin, dirs, w)


func _server_shot(sid: int, origin: Vector3, dirs: PackedVector3Array, w: String) -> void:
	if not players.has(sid) or not WDB.DATA.has(w) or dirs.size() > 12:
		return
	var sp: Player = players[sid]
	var st: Dictionary = _hp_host.get(sid, {})
	if st.is_empty() or not st["alive"] or st["choosing"] or ended:
		return
	var wd: Dictionary = WDB.DATA[w]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_shot.get(sid, -9.0)) < float(wd["interval"]) * 0.7:
		return
	_last_shot[sid] = now
	var space := get_world_3d().direct_space_state
	# حماية من الإطلاق عبر الجدران: الرأس → نقطة الكاميرا يجب أن يكون الطريق خاليًا
	var head := sp.global_position + Vector3(0, 1.45, 0)
	if origin.distance_to(head) > 1.6:
		origin = head + (origin - head).normalized() * 0.3
	var wq := PhysicsRayQueryParameters3D.create(head, origin, 1)
	if not space.intersect_ray(wq).is_empty():
		origin = head
	var dmg_map: Dictionary = {}   # victim id -> {dmg, head}
	var ends := PackedVector3Array()
	for d in dirs:
		var dn := d.normalized()
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dn * float(wd["range"]), 3)
		q.exclude = [sp.get_rid()]
		var h := space.intersect_ray(q)
		if h.is_empty():
			ends.append(origin + dn * float(wd["range"]))
			continue
		ends.append(h.position)
		var col = h.collider
		if col is Player:
			var vp: Player = col
			var vid := vp.pid
			var vs: Dictionary = _hp_host.get(vid, {})
			if vs.is_empty() or not vs["alive"] or vs["choosing"] or float(vs["invuln"]) > 0.0:
				continue
			var dist := origin.distance_to(h.position)
			var dmg := float(wd["dmg"])
			if int(wd["pellets"]) > 1:
				dmg *= clampf(1.0 - (dist - 7.0) / 40.0, 0.25, 1.0)
			var headshot: bool = (h.position.y - vp.global_position.y) > (vp.col.position.y * 2.0 * 0.8)
			if headshot:
				dmg *= float(wd["head"])
			if not dmg_map.has(vid):
				dmg_map[vid] = {"dmg": 0.0, "head": false}
			dmg_map[vid]["dmg"] += dmg
			dmg_map[vid]["head"] = dmg_map[vid]["head"] or headshot
	_rpc_shot_fx.rpc(sid, ends, w)
	for vid in dmg_map:
		_host_damage(vid, sid, float(dmg_map[vid]["dmg"]), bool(dmg_map[vid]["head"]), w, origin)


@rpc("authority", "call_local", "unreliable")
func _rpc_shot_fx(sid: int, ends: PackedVector3Array, w: String) -> void:
	if not players.has(sid):
		return
	var p: Player = players[sid]
	if p.is_local:
		return
	p.remote_shot_fx()
	var muz := p.model.muzzle_world() if p.model else p.global_position
	for e in ends:
		_tracer(muz, e)
		_impact(e)
	Sfx.play3d(str(WDB.DATA[w]["sfx"]), muz, 2.0, randf_range(0.97, 1.03))


func _host_damage(vid: int, aid: int, dmg: float, head: bool, w: String, from: Vector3) -> void:
	var vp: Player = players[vid]
	var newhp := maxf(0.0, vp.hp - dmg)
	vp.hp = newhp
	_rpc_hp.rpc(vid, newhp, aid, from, head, dmg)
	if newhp <= 0.0:
		_hp_host[vid]["alive"] = false
		Net.players[vid]["deaths"] += 1
		if aid != vid:
			Net.players[aid]["kills"] += 1
		_rpc_died.rpc(vid, aid, w, head)
		_rpc_scores.rpc(Net.players)
		_respawn_q[vid] = RESPAWN_DELAY


@rpc("authority", "call_local", "reliable")
func _rpc_hp(vid: int, newhp: float, aid: int, from: Vector3, head: bool, dmg: float) -> void:
	if not players.has(vid):
		return
	var vp: Player = players[vid]
	vp.hp = newhp
	if vp.is_local:
		Sfx.play("hurt", -2.0)
		var rel := vp.cam.global_transform.affine_inverse() * from
		hud.damage_from(atan2(rel.x, -rel.z))
	elif vp.model:
		Sfx.play3d("hit", vp.global_position + Vector3(0, 1.3, 0), -4.0)
	if aid == Net.my_id() and aid != vid:
		hud.hitmarker(newhp <= 0.0, head)


@rpc("authority", "call_local", "reliable")
func _rpc_died(vid: int, kid: int, w: String, head: bool) -> void:
	if not players.has(vid):
		return
	var vp: Player = players[vid]
	vp.set_dead(true)
	vp.hp = 0.0
	var vn: String = Net.players.get(vid, {}).get("name", "?")
	var kn: String = Net.players.get(kid, {}).get("name", "?")
	var wn: String = WDB.DATA[w]["name"] if WDB.DATA.has(w) else ""
	var txt := ("%s قتل %s  [%s]%s" % [kn, vn, wn, " 🎯" if head else ""]) if kid != vid else (vn + " سقط")
	hud.add_feed(txt, kid == Net.my_id() or vid == Net.my_id())
	if vp.is_local:
		Sfx.play("die", 0.0)
		_death_active = true
		_death_t = RESPAWN_DELAY
		hud.show_death(kn if kid != vid else "", _death_t)
		vp.vm.visible = false
		if hud.choose_open:
			hud.hide_choose()
	else:
		Sfx.play3d("die", vp.global_position + Vector3(0, 1.0, 0), -2.0)


@rpc("authority", "call_local", "reliable")
func _rpc_scores(pl: Dictionary) -> void:
	if not Net.is_host:
		Net.players = pl
	hud.refresh_scores()


@rpc("authority", "call_local", "unreliable")
func _rpc_time(t: float) -> void:
	if not Net.is_host:
		Net.time_left = t


@rpc("authority", "call_local", "reliable")
func _rpc_end(rows: Array) -> void:
	ended = true
	frozen = true
	if local:
		local.fire_up()
	hud.hide_choose()
	hud.hide_death()
	Sfx.play("end", 0.0)
	hud.show_results(rows, Net.is_host)


func _leave() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ------------------------------------------------------------------ مؤثرات
func _tracer(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 1.0:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.006
	cm.bottom_radius = 0.006
	cm.height = minf(len, 6.0)
	cm.radial_segments = 4
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var dir := (b - a).normalized()
	var start := a + dir * 0.5
	mi.global_position = start + dir * cm.height * 0.5
	mi.look_at_from_position(mi.global_position, mi.global_position + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := create_tween()
	tw.tween_property(mi, "global_position", b - dir * cm.height * 0.5, minf(len / 220.0, 0.25))
	tw.tween_callback(mi.queue_free)


func _impact(pos: Vector3) -> void:
	var c := CPUParticles3D.new()
	c.one_shot = true
	c.emitting = true
	c.amount = 5
	c.lifetime = 0.35
	c.explosiveness = 1.0
	c.spread = 80.0
	c.initial_velocity_min = 1.0
	c.initial_velocity_max = 2.5
	c.gravity = Vector3(0, -6, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.8, 0.4)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = m
	c.mesh = qm
	add_child(c)
	c.global_position = pos
	get_tree().create_timer(0.6).timeout.connect(c.queue_free)


# ------------------------------------------------------------------ حلقة المضيف
func _physics_process(delta: float) -> void:
	for id in _hp_host.keys():
		if _hp_host[id]["invuln"] < 90.0 and _hp_host[id]["invuln"] > 0.0:
			_hp_host[id]["invuln"] -= delta
	if _death_active and hud:
		_death_t -= delta
		hud.update_death(maxf(_death_t, 0.0))
	if not Net.is_host or ended:
		return
	Net.time_left -= delta
	_time_sync -= delta
	if _time_sync <= 0.0:
		_time_sync = 1.0
		_rpc_time.rpc(Net.time_left)
	if Net.time_left <= 0.0:
		_finish()
		return
	for id in _respawn_q.keys():
		_respawn_q[id] -= delta
		if _respawn_q[id] <= 0.0:
			_respawn_q.erase(id)
			if players.has(id):
				_host_respawn(id, false)
	_heal_tick -= delta
	if _heal_tick <= 0.0:
		_heal_tick = 0.2
		for id in players:
			var p: Player = players[id]
			var st: Dictionary = _hp_host.get(id, {})
			if st.is_empty() or not st["alive"] or p.hp >= 100.0 or p.hp <= 0.0:
				continue
			for h in heals:
				var dx: float = p.global_position.x - h.x
				var dz: float = p.global_position.z - h.z
				if dx * dx + dz * dz < HEAL_RADIUS * HEAL_RADIUS and absf(p.global_position.y - h.y) < 2.2:
					p.hp = minf(100.0, p.hp + 7.0)
					_rpc_heal.rpc(id, p.hp)
					break


@rpc("authority", "call_local", "unreliable")
func _rpc_heal(id: int, hp: float) -> void:
	if not players.has(id):
		return
	var p: Player = players[id]
	p.hp = hp
	if p.is_local:
		p.heal_flash()
		Sfx.play("heal", -10.0)


func _finish() -> void:
	ended = true
	var rows: Array = []
	for id in Net.players:
		rows.append({"id": id, "name": Net.players[id]["name"], "kills": int(Net.players[id]["kills"]), "deaths": int(Net.players[id]["deaths"])})
	rows.sort_custom(func(a, b) -> bool: return a["kills"] > b["kills"])
	_rpc_end.rpc(rows)

class_name Player
extends CharacterBody3D
## لاعب (محلي أو بعيد). المحلي: تحكّم + كاميرا + يدان وسلاح. البعيد: نموذج شخصية يُحدَّث من الشبكة.

const WALK := 4.7
const SPRINT := 7.2
const CROUCH_SPEED := 2.5
const SLIDE_START := 10.0
const SLIDE_TIME := 0.95
const JUMP_V := 5.4
const GRAVITY := 15.0
const STEP_H := 0.45
const STAND_H := 1.78
const CROUCH_H := 1.15
const EYE_STAND := 1.62
const EYE_CROUCH := 1.08
const RADIUS := 0.36

var pid: int = 0
var pname: String = ""
var character: String = "mummy"
var is_local: bool = false
var arena: Node = null

# حالة اللعب
var hp: float = 100.0
var alive: bool = true
var choosing: bool = true
var invuln: float = 0.0
var wid: String = "m4"
var wd: Dictionary = WDB.DATA["m4"]
var ammo: int = 30
var reloading: bool = false
var _reload_t: float = 0.0
var _reload_total: float = 1.0
var _reload_beats: Array = []
var _cool: float = 0.0
var _shot_idx: int = 0
var _idle_t: float = 0.0
var _burst_yaw: float = 0.0

# تحكم
var yaw: float = 0.0
var pitch: float = 0.0
var rec_p: float = 0.0           # ارتداد مرئي (يعود تدريجيًا)
var rec_y: float = 0.0
var crouched: bool = false
var sliding: bool = false
var _slide_t: float = 0.0
var _slide_dir: Vector3 = Vector3.ZERO
var ads: bool = false
var ads_t: float = 0.0
var sprinting: bool = false
var _want_jump: bool = false
var _coyote: float = 0.0
var _step_off: float = 0.0
var _eye: float = EYE_STAND
var _hh: float = STAND_H
var _fire_held: bool = false
var _fire_clicked: bool = false
var _spread_now: float = 0.0
var _steps_t: float = 0.0
var _was_floor: bool = true
var _fall_speed: float = 0.0
var _heal_flash: float = 0.0
var _shake: float = 0.0
var _look_d: Vector2 = Vector2.ZERO

# مراجع
var col: CollisionShape3D
var cam_root: Node3D
var cam: Camera3D
var vm: ViewModel
var model: CharModel
var ui: Node = null   # HUD (للمحلي)
var tui: TouchUI = null
var _prev_pos: Vector3
var _cur_pos: Vector3

# شبكة (للبعيد)
var _net_pos: Vector3
var _net_vel: Vector3
var _net_age: float = 0.0
var _vis_pos: Vector3
var _net_yaw: float = 0.0
var _net_pitch: float = 0.0
var _net_flags: int = 0
var _send_t: float = 0.0
var _remote_aim_pitch: float = 0.0


func setup(id: int, nm: String, chr: String, ar: Node) -> void:
	pid = id
	pname = nm
	character = chr
	arena = ar
	name = "P_%d" % id
	set_multiplayer_authority(id)
	is_local = (id == Net.my_id())
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.5
	floor_stop_on_slope = true
	floor_constant_speed = true
	max_slides = 5
	col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = STAND_H
	col.shape = cap
	col.position.y = STAND_H * 0.5
	add_child(col)
	if is_local:
		_setup_local()
	else:
		model = CharModel.new()
		add_child(model)
		model.build(character)
		model.set_weapon(wid)


func _setup_local() -> void:
	cam_root = Node3D.new()
	cam_root.top_level = true
	add_child(cam_root)
	cam = Camera3D.new()
	cam.near = 0.025
	cam.far = 220.0
	cam.fov = Settings.fov
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.current = true
	cam_root.add_child(cam)
	vm = ViewModel.new()
	vm.wid = wid
	cam.add_child(vm)
	var listener := AudioListener3D.new()
	cam.add_child(listener)
	listener.make_current()


func equip(id: String, full: bool = true) -> void:
	wid = id
	wd = WDB.DATA[id]
	if full:
		ammo = int(wd["mag"])
	reloading = false
	_shot_idx = 0
	if is_local:
		vm.set_weapon(id)
		ads = false
	elif model:
		model.set_weapon(id)


func teleport(pos: Vector3, yaw_v: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	yaw = yaw_v
	pitch = 0.0
	_prev_pos = pos
	_cur_pos = pos
	_net_pos = pos
	_vis_pos = pos
	rec_p = 0.0
	rec_y = 0.0
	sliding = false
	crouched = false
	if is_local and cam_root:
		cam_root.global_position = pos + Vector3(0, EYE_STAND, 0)


func set_dead(d: bool) -> void:
	alive = not d
	if d:
		reloading = false
		ads = false
		sliding = false
		if is_local:
			vm.cancel_reload()
			if tui:
				tui.release_all()
		elif model:
			model.die()
	else:
		hp = 100.0
		if not is_local and model:
			model.revive()


# ------------------------------------------------------------------ دخل
func fire_down() -> void:
	_fire_held = true
	_fire_clicked = true


func fire_up() -> void:
	_fire_held = false


func toggle_ads() -> void:
	if not alive or choosing:
		return
	ads = not ads
	if ads and sprinting:
		sprinting = false


func press_jump() -> void:
	_want_jump = true


func press_crouch() -> void:
	if not alive or choosing:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > SPRINT * 0.8 and is_on_floor()
	if moving and not sliding and not crouched:
		_start_slide()
	elif sliding:
		sliding = false
		crouched = true
	else:
		crouched = not crouched


func _start_slide() -> void:
	sliding = true
	_slide_t = SLIDE_TIME
	_slide_dir = Vector3(velocity.x, 0, velocity.z).normalized()
	Sfx.play("slide", -6.0)
	crouched = false


func press_reload() -> void:
	if not alive or choosing or reloading or ammo >= int(wd["mag"]):
		return
	_begin_reload()


func _begin_reload() -> void:
	reloading = true
	_reload_total = float(wd["reload_empty"] if ammo == 0 else wd["reload"])
	_reload_t = 0.0
	ads = false
	_reload_beats = []
	if wd["mag_sound"]:
		_reload_beats = [[0.22, "mag_out"], [0.62, "mag_in"], [0.88, "bolt" if wid != "m1014" else "pump"]]
	else:
		_reload_beats = [[0.2, "shell_in"], [0.4, "shell_in"], [0.6, "shell_in"], [0.8, "pump"]]
	if is_local:
		vm.start_reload(_reload_total)
		Sfx.play("empty_whoosh", -10.0)


# ------------------------------------------------------------------ حلقة الفيزياء
func _physics_process(delta: float) -> void:
	if is_local:
		_local_physics(delta)
	else:
		_remote_physics(delta)


func _local_physics(delta: float) -> void:
	_prev_pos = _cur_pos
	if invuln > 0.0:
		invuln -= delta
	# إدخال
	var mv := Vector2.ZERO
	if tui:
		mv = tui.stick_vec
	mv += _kb_move()
	if mv.length() > 1.0:
		mv = mv.normalized()
	var can_act: bool = alive and not choosing and not (arena and arena.frozen)
	if not can_act:
		mv = Vector2.ZERO
	# سرعة الاتجاه
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var wish := (right * mv.x + forward * -mv.y)
	var want_sprint: bool = mv.length() > 0.9 and mv.y < -0.3 and not ads and not reloading and not crouched and can_act and not _fire_held
	sprinting = want_sprint
	var target_speed := WALK
	if sprinting:
		target_speed = SPRINT
	if crouched:
		target_speed = CROUCH_SPEED
	if ads:
		target_speed *= 0.6
	target_speed *= float(wd["speed"])
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = 0.12
		_fall_speed = 0.0
	else:
		_coyote = maxf(0.0, _coyote - delta)

	var hv := Vector3(velocity.x, 0, velocity.z)
	if sliding:
		_slide_t -= delta
		var k := clampf(_slide_t / SLIDE_TIME, 0.0, 1.0)
		hv = _slide_dir * lerpf(3.0, SLIDE_START, k * k)
		if _slide_t <= 0.0 or not on_floor and _slide_t < SLIDE_TIME * 0.7:
			sliding = false
			crouched = true
	else:
		var accel := 26.0 if on_floor else 5.5
		if wish.length() < 0.01 and on_floor:
			accel = 30.0
		hv = hv.move_toward(wish * target_speed, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not on_floor:
		velocity.y -= GRAVITY * delta
		_fall_speed = -velocity.y
	elif velocity.y < 0.0:
		velocity.y = -0.5
	if _want_jump:
		_want_jump = false
		if can_act and _coyote > 0.0:
			if sliding:
				sliding = false
			if crouched:
				crouched = false
			velocity.y = JUMP_V
			_coyote = 0.0
			Sfx.play("step", -6.0, 1.3)
	var pre := global_position
	move_and_slide()
	_try_step(wish, delta)
	if on_floor == false and is_on_floor() and _fall_speed > 6.0:
		Sfx.play("land", clampf(-12.0 + _fall_speed, -12.0, 0.0))
		_shake = minf(_fall_speed * 0.01, 0.1)
	_cur_pos = global_position
	# ارتفاع القامة
	var tgt_h := CROUCH_H if (crouched or sliding) else STAND_H
	if not crouched and not sliding and tgt_h < _hh + 0.01:
		pass
	if (crouched or sliding):
		_hh = move_toward(_hh, CROUCH_H, delta * 7.0)
	else:
		if _can_stand():
			_hh = move_toward(_hh, STAND_H, delta * 7.0)
		else:
			crouched = true
			_hh = move_toward(_hh, CROUCH_H, delta * 7.0)
	var cap := col.shape as CapsuleShape3D
	cap.height = _hh
	col.position.y = _hh * 0.5
	var eye_tgt := EYE_CROUCH if (crouched or sliding) else EYE_STAND
	_eye = move_toward(_eye, eye_tgt, delta * 5.5)
	# خطوات
	var spd := Vector2(velocity.x, velocity.z).length()
	if on_floor and spd > 1.5 and not sliding:
		_steps_t -= delta * spd * 0.22
		if _steps_t <= 0.0:
			_steps_t = 1.0
			Sfx.play("step", -14.0 if crouched else -9.0, randf_range(0.9, 1.1))
	# سقوط خارج الخريطة
	if global_position.y < -12.0 and arena:
		arena.request_unstuck()
	# سلاح
	_weapon_logic(delta, spd)
	# إرسال الحالة
	_send_t -= delta
	if _send_t <= 0.0:
		_send_t = 1.0 / 20.0
		var flags := 0
		if crouched:
			flags |= 1
		if sliding:
			flags |= 2
		if is_on_floor():
			flags |= 4
		if ads:
			flags |= 8
		net_state.rpc(global_position, yaw, pitch + rec_p, flags, velocity)


func _kb_move() -> Vector2:
	if DisplayServer.get_name() == "headless":
		return Vector2.ZERO
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		v.y += 1.0
	if Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		v.x += 1.0
	return v


func _can_stand() -> bool:
	if _hh >= STAND_H - 0.01:
		return true
	var shape := col.shape as CapsuleShape3D
	var q := PhysicsShapeQueryParameters3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = RADIUS - 0.03
	cs.height = STAND_H
	q.shape = cs
	q.transform = Transform3D(Basis(), global_position + Vector3(0, STAND_H * 0.5 + 0.04, 0))
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _try_step(wish: Vector3, delta: float) -> void:
	if wish.length() < 0.1 or not is_on_floor() or sliding:
		return
	if get_slide_collision_count() == 0:
		return
	var dirn := wish.normalized()
	var hit_wall := false
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if absf(n.y) < 0.3 and n.dot(dirn) < -0.2:
			hit_wall = true
	if not hit_wall:
		return
	var t := global_transform
	var up := Vector3.UP * STEP_H
	if test_move(t, up):
		return
	var t2 := t.translated(up)
	var fwd := dirn * 0.22
	if test_move(t2, fwd):
		return
	var t3 := t2.translated(fwd)
	var down := KinematicCollision3D.new()
	if test_move(t3, Vector3.DOWN * (STEP_H + 0.05), down):
		var rise := STEP_H - down.get_travel().length() * 1.0
		rise = clampf(rise, 0.0, STEP_H)
		if rise < 0.03:
			return
		global_position += Vector3(0, rise + 0.01, 0) + fwd
		_step_off -= rise


func _remote_physics(delta: float) -> void:
	_net_age += delta
	var predicted := _net_pos + _net_vel * minf(_net_age, 0.12)
	global_position = predicted
	if invuln > 0.0:
		invuln -= delta
	var crouch := (_net_flags & 1) != 0
	var slide := (_net_flags & 2) != 0
	var capsule := col.shape as CapsuleShape3D
	var hgt := CROUCH_H if (crouch or slide) else STAND_H
	capsule.height = hgt
	col.position.y = hgt * 0.5


func _process(delta: float) -> void:
	if is_local:
		_local_visual(delta)
	else:
		_remote_visual(delta)


func _remote_visual(delta: float) -> void:
	if model == null:
		return
	_vis_pos = _vis_pos.lerp(global_position, 1.0 - exp(-16.0 * delta))
	model.top_level = true
	model.global_position = _vis_pos
	var ty := _net_yaw
	model.rotation.y = lerp_angle(model.rotation.y, ty, 1.0 - exp(-18.0 * delta))
	_remote_aim_pitch = lerpf(_remote_aim_pitch, _net_pitch, 1.0 - exp(-14.0 * delta))
	var spd := Vector2(_net_vel.x, _net_vel.y).length() if false else Vector2(_net_vel.x, _net_vel.z).length()
	model.pose(delta, spd, _remote_aim_pitch, (_net_flags & 1) != 0, (_net_flags & 4) != 0, (_net_flags & 2) != 0)
	model.visible = alive or model.dead


func _local_visual(delta: float) -> void:
	# نظر: لمس + جيروسكوب
	var look := Vector2.ZERO
	if tui:
		look = tui.take_look()
	look += _kb_look()
	var can_look: bool = alive and not (arena and arena.frozen) and not (ui and ui.menu_open)
	var fov_ratio := cam.fov / Settings.fov
	var sens := Settings.look_sens
	if ads:
		sens *= Settings.scope_mult if wd["scope"] else Settings.ads_mult
		sens *= clampf(fov_ratio, 0.2, 1.0) if not wd["scope"] else clampf(fov_ratio * 1.6, 0.25, 1.0)
	if can_look:
		var dy := look.x * sens
		var dp := look.y * sens * (-1.0 if Settings.invert_y else 1.0)
		if Settings.gyro_on and DisplayServer.get_name() != "headless":
			var g := Input.get_gyroscope()
			var gs := rad_to_deg(1.0) * delta * Settings.gyro_sens * 0.55 * (clampf(fov_ratio, 0.25, 1.0) if ads else 1.0)
			dy += -g.y * gs
			dp += -g.x * gs
		yaw -= deg_to_rad(dy)
		pitch = clampf(pitch - deg_to_rad(dp), deg_to_rad(-88.0), deg_to_rad(88.0))
	_look_d = look
	# ارتداد: يعود تدريجيًا
	var rec_rate := float(wd["rec_recover"])
	rec_p = lerpf(rec_p, 0.0, clampf(delta * rec_rate * 0.55, 0.0, 1.0))
	rec_y = lerpf(rec_y, 0.0, clampf(delta * rec_rate * 0.55, 0.0, 1.0))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 0.5)
	# كاميرا ممهّدة بين خطوات الفيزياء
	var f := Engine.get_physics_interpolation_fraction()
	var pos := _prev_pos.lerp(_cur_pos, f) if _prev_pos != Vector3.ZERO else global_position
	_step_off = lerpf(_step_off, 0.0, clampf(delta * 9.0, 0.0, 1.0))
	var eye_pos := pos + Vector3(0, _eye + _step_off, 0)
	# الرأس لا يخترق الجدران: مسح كروي من مركز الرأس نحو موضع الكاميرا
	var head := pos + Vector3(0, _eye - 0.18 + _step_off, 0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(head, eye_pos + Vector3(0, 0.0, 0), 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		eye_pos = hit.position + hit.normal * 0.06
	cam_root.global_position = eye_pos
	var shake_v := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
	var dead_roll := 0.0
	if not alive:
		dead_roll = deg_to_rad(55.0)
		cam_root.global_position.y = lerpf(cam_root.global_position.y, pos.y + 0.35, 0.1)
	var tilt := 0.0
	if sliding:
		tilt = deg_to_rad(-4.0)
	cam_root.rotation = Vector3(pitch + rec_p + shake_v.x, yaw + rec_y + shake_v.y, dead_roll + tilt)
	# FOV
	var base := Settings.fov
	var ads_goal := float(wd["ads_fov"])
	ads_t = move_toward(ads_t, 1.0 if (ads and alive) else 0.0, delta * (7.0 if not wd["scope"] else 5.5))
	var sprint_fov := 3.0 if sprinting else 0.0
	cam.fov = lerpf(base + sprint_fov, ads_goal, smoothstep(0.0, 1.0, ads_t))
	# مجسّم اليد
	vm.ads = ads_t
	var scoped: bool = wd["scope"] and ads_t > 0.82
	vm.hide_weapon = scoped or not alive
	vm.visible = alive
	# قرب الجدار
	var fwd_ray := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_transform.basis.z * 1.05, 1)
	var fh := space.intersect_ray(fwd_ray)
	var wall_k := 0.0
	if not fh.is_empty():
		wall_k = clampf(1.0 - (cam.global_position.distance_to(fh.position) - 0.3) / 0.6, 0.0, 1.0)
	vm.wall = lerpf(vm.wall, wall_k, clampf(delta * 14.0, 0.0, 1.0))
	var spd := Vector2(velocity.x, velocity.z).length()
	var ratio := clampf(spd / SPRINT, 0.0, 1.0)
	vm.step(delta, ratio, is_on_floor(), _look_d, crouched, sliding)
	if _heal_flash > 0.0:
		_heal_flash -= delta
	if ui:
		ui.update_state(self)


func _kb_look() -> Vector2:
	if DisplayServer.get_name() == "headless":
		return Vector2.ZERO
	return Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_accum += (event as InputEventMouseMotion).relative
var _mouse_accum := Vector2.ZERO


# ------------------------------------------------------------------ سلاح
func _current_spread() -> float:
	var s: float
	if ads:
		s = float(wd["spread_ads"])
	else:
		s = float(wd["spread_hip"])
	var spd := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		s = maxf(s, float(wd["spread_air"]))
	elif spd > 1.0:
		s += float(wd["spread_move"]) * clampf(spd / SPRINT, 0.0, 1.0) * (0.5 if ads else 1.0)
	if crouched:
		s *= 0.7
	s += minf(_shot_idx, 10) * float(wd["spread_hip"]) * 0.04
	return s


func _weapon_logic(delta: float, spd: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	_idle_t += delta
	if _idle_t > float(wd["interval"]) + 0.28:
		_shot_idx = maxi(0, _shot_idx - 1) if _idle_t > 0.6 else _shot_idx
		if _idle_t > 0.45:
			_shot_idx = 0
	_spread_now = lerpf(_spread_now, _current_spread(), clampf(delta * 14.0, 0.0, 1.0))
	if reloading:
		_reload_t += delta
		var p := _reload_t / _reload_total
		for b in _reload_beats:
			if p >= float(b[0]) and not b.has(true):
				Sfx.play(str(b[1]), -4.0)
				b.append(true)
		if _reload_t >= _reload_total:
			reloading = false
			ammo = int(wd["mag"])
	var can: bool = alive and not choosing and not reloading and not (arena and arena.frozen)
	if can and _cool <= 0.0:
		var want_shot := false
		if wd["auto"]:
			want_shot = _fire_held
		else:
			want_shot = _fire_clicked
		if want_shot:
			if ammo > 0:
				_fire()
			else:
				if _fire_clicked:
					Sfx.play("dry", -4.0)
				_begin_reload()
	_fire_clicked = false
	if alive and not choosing and ammo == 0 and not reloading and _cool <= 0.0:
		_begin_reload()


func _fire() -> void:
	ammo -= 1
	_cool = float(wd["interval"])
	_idle_t = 0.0
	var cam_t := cam.global_transform
	var origin := cam_t.origin
	var spread := _spread_now
	var dirs := PackedVector3Array()
	var n := int(wd["pellets"])
	for i in n:
		var d := -cam_t.basis.z
		if spread > 0.001 or n > 1:
			var ang := deg_to_rad(spread) * sqrt(randf())
			var rot := randf() * TAU
			d = d.rotated(cam_t.basis.x, sin(rot) * ang).rotated(cam_t.basis.y, cos(rot) * ang)
		dirs.append(d.normalized())
	# ارتداد
	var ramp := 1.0 + float(wd["rec_ramp"]) * minf(_shot_idx, 14)
	var pk := float(wd["rec_pitch"]) * ramp
	var yk := float(wd["rec_yaw"]) * ramp
	var m := 1.0
	if ads:
		m *= float(wd["rec_ads"])
	if crouched:
		m *= 0.78
	if not is_on_floor():
		m *= 1.5
	_burst_yaw += 0.55
	var drift := sin(_burst_yaw) * 0.55
	var kick_p := deg_to_rad(pk * m)
	var kick_y := deg_to_rad(yk * m * (drift + randf_range(-0.7, 0.7)))
	rec_p += kick_p * 0.62
	pitch = minf(pitch + kick_p * 0.38, deg_to_rad(88.0))
	rec_y += kick_y * 0.6
	yaw -= kick_y * 0.4
	_shot_idx += 1
	vm.fire_visual()
	_shake = maxf(_shake, 0.0015 * (3.0 if wid == "awm" else 1.0))
	Sfx.play(str(wd["sfx"]), 0.0, randf_range(0.97, 1.03))
	if wid == "awm":
		ads_hold_after_shot()
	if arena:
		arena.local_shot(self, origin, dirs, wid)
	_spawn_casing()
	if ui:
		ui.on_fire(self)


func ads_hold_after_shot() -> void:
	pass


func _spawn_casing() -> void:
	if wid == "awm" or not is_local:
		return
	var c := CPUParticles3D.new()
	c.one_shot = true
	c.emitting = true
	c.amount = 1
	c.lifetime = 0.7
	c.explosiveness = 1.0
	c.local_coords = false
	c.direction = cam.global_transform.basis.x + Vector3(0, 0.8, 0.2)
	c.spread = 20.0
	c.initial_velocity_min = 1.6
	c.initial_velocity_max = 2.4
	c.gravity = Vector3(0, -9.8, 0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0045
	mesh.bottom_radius = 0.0045
	mesh.height = 0.03 if wid != "m1014" else 0.05
	mesh.radial_segments = 6
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.2) if wid != "m1014" else Color(0.75, 0.15, 0.1)
	mat.metallic = 0.6
	mesh.material = mat
	c.mesh = mesh
	c.angular_velocity_min = 300.0
	c.angular_velocity_max = 700.0
	arena.add_child(c)
	c.global_position = vm.weapon.global_transform * (wd["eject"] as Vector3)
	get_tree().create_timer(1.2).timeout.connect(c.queue_free)


# ------------------------------------------------------------------ شبكة
@rpc("authority", "unreliable_ordered", "call_remote")
func net_state(p: Vector3, y: float, pt: float, flags: int, vel: Vector3) -> void:
	_net_pos = p
	_net_vel = vel
	_net_yaw = y
	_net_pitch = pt
	_net_flags = flags
	_net_age = 0.0


func remote_shot_fx() -> void:
	if model:
		model.shot_flash()


func heal_flash() -> void:
	_heal_flash = 0.4


func take_heal_flash() -> bool:
	return _heal_flash > 0.0

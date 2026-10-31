extends Node
## الشبكة: استضافة/انضمام عبر Wi-Fi (ENet) + اكتشاف الغرف عبر UDP + قائمة اللاعبين.

signal roster_changed
signal join_failed(reason: String)
signal left_room
signal rooms_changed
signal match_go

const PORT := 47777
const DISC_PORT := 47778
const MAX_PLAYERS := 4
const MATCH_SECONDS := 300.0
const PROTO := "CRWD1"

var players: Dictionary = {}     # id -> {name, character, kills, deaths}
var is_host: bool = false
var in_match: bool = false
var room_name: String = ""
var found_rooms: Dictionary = {} # ip -> {name, count, t}
var time_left: float = MATCH_SECONDS
var online: bool = false

var _tx: PacketPeerUDP
var _rx: PacketPeerUDP
var _bcast_t: float = 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void:
		_close()
		join_failed.emit("تعذّر الاتصال بالمضيف"))
	multiplayer.server_disconnected.connect(func() -> void:
		_close()
		left_room.emit())


func my_id() -> int:
	return multiplayer.get_unique_id() if online else 1


func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		if a.begins_with("127.") or a.contains(":") or a.begins_with("169.254."):
			continue
		out.append(a)
	return out


# ---------------------------------------------------------------- اكتشاف الغرف
func start_listening() -> void:
	if _rx:
		return
	_rx = PacketPeerUDP.new()
	_rx.set_broadcast_enabled(true)
	if _rx.bind(DISC_PORT, "*") != OK:
		_rx = null


func stop_listening() -> void:
	if _rx:
		_rx.close()
		_rx = null
	found_rooms.clear()


func _process(delta: float) -> void:
	if _rx:
		while _rx.get_available_packet_count() > 0:
			var data := _rx.get_packet().get_string_from_utf8()
			var ip := _rx.get_packet_ip()
			var j = JSON.parse_string(data)
			if j is Dictionary and j.get("p", "") == PROTO:
				found_rooms[ip] = {"name": j.get("n", "?"), "count": j.get("c", 1), "t": Time.get_ticks_msec(), "match": j.get("m", false)}
				rooms_changed.emit()
		var changed := false
		for ip in found_rooms.keys():
			if Time.get_ticks_msec() - int(found_rooms[ip]["t"]) > 4500:
				found_rooms.erase(ip)
				changed = true
		if changed:
			rooms_changed.emit()
	if online and is_host and _tx:
		_bcast_t -= delta
		if _bcast_t <= 0.0:
			_bcast_t = 1.0
			var pkt := JSON.stringify({"p": PROTO, "n": room_name, "c": players.size(), "m": in_match}).to_utf8_buffer()
			var targets: Array = ["255.255.255.255"]
			for a in local_ips():
				var parts: PackedStringArray = a.split(".")
				if parts.size() == 4:
					targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
			for t in targets:
				_tx.set_dest_address(t, DISC_PORT)
				_tx.put_packet(pkt)


# ---------------------------------------------------------------- استضافة/انضمام
func host_game(room: String) -> bool:
	_close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, MAX_PLAYERS - 1) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	online = true
	is_host = true
	room_name = room
	in_match = false
	players.clear()
	players[1] = {"name": Settings.player_name, "character": Settings.character, "kills": 0, "deaths": 0}
	_tx = PacketPeerUDP.new()
	_tx.set_broadcast_enabled(true)
	stop_listening()
	roster_changed.emit()
	return true


func join_game(ip: String) -> bool:
	_close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip.strip_edges(), PORT) != OK:
		join_failed.emit("عنوان غير صالح")
		return false
	multiplayer.multiplayer_peer = peer
	online = true
	is_host = false
	stop_listening()
	return true


func leave() -> void:
	_close()
	left_room.emit()


func _close() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	online = false
	is_host = false
	in_match = false
	players.clear()
	if _tx:
		_tx.close()
		_tx = null


func _on_connected() -> void:
	_register.rpc_id(1, Settings.player_name, Settings.character)


func _on_peer_connected(id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if is_host and players.has(id):
		players.erase(id)
		_sync_roster.rpc(players)
		roster_changed.emit()
		var arena := get_tree().root.get_node_or_null("Arena")
		if arena and arena.has_method("peer_left"):
			arena.peer_left(id)


@rpc("any_peer", "reliable")
func _register(pname: String, character: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS:
		_reject.rpc_id(id, "الغرفة ممتلئة (4 لاعبين)")
		return
	var base := pname.strip_edges().left(14)
	if base == "":
		base = "لاعب"
	var nm := base
	var k := 2
	var taken := true
	while taken:
		taken = false
		for pid in players:
			if players[pid]["name"] == nm:
				taken = true
		if taken:
			nm = "%s%d" % [base, k]
			k += 1
	players[id] = {"name": nm, "character": character if character in ["mummy", "girl"] else "mummy", "kills": 0, "deaths": 0}
	_sync_roster.rpc(players)
	roster_changed.emit()
	if in_match:
		_match_go.rpc_id(id, time_left)


@rpc("authority", "reliable")
func _reject(reason: String) -> void:
	_close()
	join_failed.emit(reason)


@rpc("authority", "reliable")
func _sync_roster(p: Dictionary) -> void:
	if is_host:
		return
	players = p
	roster_changed.emit()


func start_match() -> void:
	if not is_host:
		return
	for id in players:
		players[id]["kills"] = 0
		players[id]["deaths"] = 0
	in_match = true
	time_left = MATCH_SECONDS
	_sync_roster.rpc(players)
	_match_go.rpc(MATCH_SECONDS)


@rpc("authority", "call_local", "reliable")
func _match_go(t: float) -> void:
	in_match = true
	time_left = t
	match_go.emit()
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func back_to_lobby() -> void:
	if is_host:
		in_match = false
		_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _to_lobby() -> void:
	in_match = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

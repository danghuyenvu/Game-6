extends Node3D

const PLAYER_SCENE := preload("res://addons/proto_controller/proto_controller.tscn")

@onready var players: Node3D = $Players
@onready var editor_player: Node = $ProtoController

var _spawned_peers: Array[int] = []

var _spawn_points := [
	Vector3(-6.35, 0.11, 3.10),
	Vector3(-3.35, 0.11, 3.10),
	Vector3(-6.35, 0.11, 6.10),
	Vector3(-3.35, 0.11, 6.10),
]

func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		if editor_player and editor_player.has_method("apply_authority"):
			editor_player.apply_authority()
		return

	call_deferred("_start_multiplayer")

func _start_multiplayer() -> void:
	if not _has_active_multiplayer_peer():
		call_deferred("_start_multiplayer")
		return

	var peer_id := multiplayer.get_unique_id()
	_activate_temporary_local_player(peer_id)
	if multiplayer.is_server():
		if not multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.connect(_on_peer_connected)
		_request_spawn(peer_id)
	else:
		_request_spawn.rpc_id(1, peer_id)
	call_deferred("_ensure_local_player")

func _on_peer_connected(peer_id: int) -> void:
	for spawned_peer_id in _spawned_peers:
		_spawn_player_everywhere.rpc_id(peer_id, spawned_peer_id, _spawned_peers.find(spawned_peer_id), _get_player_weapon_slot(spawned_peer_id))

@rpc("any_peer", "call_remote", "reliable")
func _request_spawn(peer_id: int) -> void:
	if not _is_server_context():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != 0:
		peer_id = sender_id

	if not _spawned_peers.has(peer_id):
		_spawned_peers.append(peer_id)
	var weapon_slot := _get_player_weapon_slot(peer_id)
	_spawn_player_everywhere.rpc(peer_id, _spawned_peers.find(peer_id), weapon_slot)
	_spawn_player_everywhere(peer_id, _spawned_peers.find(peer_id), weapon_slot)

@rpc("authority", "call_remote", "reliable")
func _spawn_player_everywhere(peer_id: int, spawn_index: int, weapon_slot: StringName = &"secondary") -> void:
	var player_name := str(peer_id)
	if players.has_node(player_name):
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = player_name
	player.set_multiplayer_authority(peer_id)
	player.add_to_group(&"player")
	player.global_position = _spawn_points[spawn_index % _spawn_points.size()]
	players.add_child(player, true)

	var weapon_manager = player.get_node_or_null("Head/Camera3D/WeaponManager")
	if weapon_manager and weapon_manager.has_method("equip_slot"):
		weapon_manager.equip_slot(weapon_slot, peer_id == _safe_peer_id())

	if peer_id == _safe_peer_id() and player.has_method("apply_authority"):
		player.call_deferred("apply_authority")
		call_deferred("_remove_temporary_local_player")

func _ensure_local_player() -> void:
	if not _has_active_multiplayer_peer():
		call_deferred("_ensure_local_player")
		return

	var peer_id := multiplayer.get_unique_id()
	if players.has_node(str(peer_id)):
		return

	if multiplayer.is_server():
		_request_spawn(peer_id)
	else:
		_request_spawn.rpc_id(1, peer_id)

	var tree := get_tree()
	if tree:
		await tree.create_timer(0.5).timeout
		call_deferred("_ensure_local_player")

func _has_active_multiplayer_peer() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _is_server_context() -> bool:
	if not _has_active_multiplayer_peer():
		return false
	return multiplayer.is_server()

func _safe_peer_id() -> int:
	if not _has_active_multiplayer_peer():
		return 0
	return multiplayer.get_unique_id()

func _activate_temporary_local_player(peer_id: int) -> void:
	if not editor_player or not is_instance_valid(editor_player):
		return
	editor_player.set_multiplayer_authority(peer_id)
	if editor_player.has_method("apply_authority"):
		editor_player.call_deferred("apply_authority")

func _remove_temporary_local_player() -> void:
	if editor_player and is_instance_valid(editor_player):
		editor_player.queue_free()

func _get_player_weapon_slot(peer_id: int) -> StringName:
	var player := players.get_node_or_null(str(peer_id))
	if player == null:
		return &"secondary"

	var weapon_manager = player.get_node_or_null("Head/Camera3D/WeaponManager")
	if weapon_manager and weapon_manager.has_method("get_current_slot"):
		var slot: StringName = weapon_manager.get_current_slot()
		if slot != &"":
			return slot
	return &"secondary"

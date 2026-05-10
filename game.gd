extends Node3D

# Set this in the Inspector to your player PackedScene
@export var player_scene: PackedScene

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready():
	spawner.spawn_path = get_path()

	if multiplayer.is_server():
		# Spawn host player
		_spawn_player(multiplayer.get_unique_id())
		# Now safe to listen for incoming players
		multiplayer.peer_connected.connect(_spawn_player)
		# Tell all already-waiting clients to load the map
		load_map.rpc()

@rpc("authority", "call_remote", "reliable")
func load_map():
	pass  # client already loaded map via change_scene, this just triggers spawn

func _spawn_player(id: int):
	if has_node(str(id)):
		return
	var p = player_scene.instantiate()
	p.name = str(id)
	add_child(p, false)
	p.global_position = Vector3(randf_range(-5.0, 5.0), 5.0, randf_range(0.0, 5.0))
	# Gọi rpc để tất cả peers set authority đúng
	set_player_authority.rpc(str(id), id)

@rpc("authority", "call_local", "reliable")
func set_player_authority(player_name: String, authority_id: int):
	# Tìm node bằng tên thay vì path
	var p = get_node_or_null(player_name)
	if p:
		p.set_multiplayer_authority(authority_id)
		p.apply_authority()
		print("SET AUTHORITY: ", player_name, " → ", authority_id)
	else:
		print("NODE NOT FOUND: ", player_name)

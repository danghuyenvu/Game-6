extends Node3D

@export var player_scene: PackedScene
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready():
	spawner.spawn_path = get_path()

	if multiplayer.is_server():
		# Spawn for players already connected (including host)
		_spawn_player(multiplayer.get_unique_id())
		multiplayer.peer_connected.connect(_spawn_player)

func _spawn_player(id: int):
	var p = player_scene.instantiate()
	p.name = str(id)            # name = peer id → authority auto-assigned
	add_child(p, true)          # true = readable by network peers
	p.global_position = Vector3(-45, 4, 3 * id)

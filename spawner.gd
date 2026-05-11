extends Node3D

@export var mob_scene: PackedScene # Kéo file .tscn của Boss hoặc Mob vào đây
@export var spawn_delay: float = 5.0 # Thời gian chờ giữa mỗi lần spawn
@export var max_mobs: int = 3 # Số lượng quái tối đa tại spawner này

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var timer: Timer = $Timer

var current_mob_count: int = 0

func _ready():
	# CỰC KỲ QUAN TRỌNG: Chỉ Server mới chạy logic đếm giờ và sinh quái
	if not _is_server_context():
		return

	# 1. Thiết lập MultiplayerSpawner
	# Spawn_path phải trỏ tới Node cha mà quái sẽ được add vào (ở đây là chính nó)
	spawner.spawn_path = get_path()
	
	# 2. Đăng ký Scene vào danh sách có thể spawn (nếu chưa kéo trong Inspector)
	if mob_scene:
		spawner.add_spawnable_scene(mob_scene.resource_path)

	# 3. Chạy Timer
	timer.wait_time = spawn_delay
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func _on_timer_timeout():
	if current_mob_count < max_mobs:
		spawn_mob()

func spawn_mob():
	var mob = mob_scene.instantiate()
	
	mob.global_position = global_position + Vector3(
		randf_range(-1.5, 1.5),
		randf_range(0, 5.0), 
		randf_range(-1.5, 1.5)
	)
	mob.global_rotation.y = randf_range(0, TAU)
	# QUAN TRỌNG: Tên node phải DUY NHẤT để đồng bộ đúng giữa các máy
	mob.name = "Mob_" + str(Time.get_ticks_msec()) + "_" + str(randi())
	
	add_child(mob, true)
	
	current_mob_count += 1

	mob.tree_exited.connect(func(): 
		if is_instance_valid(self): 
			current_mob_count -= 1
	)

func _is_server_context() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return true
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return multiplayer.is_server()
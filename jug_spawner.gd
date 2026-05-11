extends Node3D

@export var mob_scene: PackedScene # Kéo file .tscn của Boss hoặc Mob vào đây
@export var spawn_delay: float = 5.0 # Thời gian chờ giữa mỗi lần spawn
@export var max_mobs: int = 2 # Số lượng quái tối đa tại spawner này

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var timer: Timer = $Timer

var current_mob_count: int = 0

func _ready():
	
	# === MULTIPLAYER SETUP ===
	
	if not multiplayer.is_server():
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
	
	# Đặt vị trí quái tại vị trí Spawner (có thể cộng thêm độ lệch ngẫu nhiên)
	mob.global_position = global_position + Vector3(
		randf_range(-2.0, 5.0),
		3.5,   # Tăng chiều cao spawn cho Boss (to hơn Mob)
		randf_range(-2.0, 5.0)
	)
	
	# QUAN TRỌNG: Tên node phải DUY NHẤT để đồng bộ đúng giữa các máy
	mob.name = "Mob_" + str(Time.get_ticks_msec()) + "_" + str(randi())
	
	# Kết nối tín hiệu để biết khi nào quái chết thì giảm đếm
	mob.tree_exited.connect(func():
		if is_instance_valid(self):
			current_mob_count -= 1
	)
	
	# Add child với tham số 'true' để đồng bộ tên node qua mạng
	add_child(mob, true)
	current_mob_count += 1
	if mob.has_method("_play_state"):
		print("[JugSpawner] Boss spawned successfully at ", mob.global_position)

func _is_server_context() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return true
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return multiplayer.is_server()
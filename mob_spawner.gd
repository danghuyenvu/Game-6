extends Node3D

@export var mob_scene: PackedScene
@export var player_path: NodePath
@export var mobs_per_wave: int = 20
@export var min_spawn_delay: float = 40.0
@export var max_spawn_delay: float = 60.0
@export var spawn_area_size: Vector3 = Vector3(108, 0, 108)
@export var spawn_height: float = -0.5
@export var min_distance_from_player: float = 30.0
@export var max_attempts: int = 20
@export var wave_spawn_window: float = 20.0  # seconds before queue is cleared

const MAX_MOBS := 30

var active_mobs := 0
var spawn_queue: Array = []
var rng := RandomNumberGenerator.new()
var player: Node3D
var player_pos := Vector3.ZERO
var parent_node: Node3D
var _timer: Timer
var _wave_window_timer: Timer
var min_dist_sq: float
var _is_spawning := false
var debug_label: Label


func _ready() -> void:
	rng.randomize()
	player = get_node_or_null(player_path)
	parent_node = get_parent()
	min_dist_sq = min_distance_from_player * min_distance_from_player

	# Next wave timer — only starts after wave window closes
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_wave_timer)

	# Wave window timer — clears queue after 20s and triggers next wave delay
	_wave_window_timer = Timer.new()
	_wave_window_timer.one_shot = true
	add_child(_wave_window_timer)
	_wave_window_timer.timeout.connect(_on_wave_window_closed)

	call_deferred("_setup_debug_label")
	_on_wave_timer()  # start first wave immediately


func _setup_debug_label() -> void:
	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.z_index = 100
	debug_label.modulate = Color.YELLOW
	get_viewport().add_child(debug_label)


func _process(_delta: float) -> void:
	if is_instance_valid(player):
		player_pos = player.global_position
	if not is_instance_valid(debug_label):
		return
	debug_label.text = "\n".join([
		"mobs in tree: %d" % get_tree().get_nodes_in_group(&"mob").size(),
		"active_mobs var: %d" % active_mobs,
		"queue size: %d" % spawn_queue.size(),
		"nav regions: %d" % NavigationServer3D.get_maps().size(),
		"physics bodies: %d" % PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS),
		"fps: %d" % Engine.get_frames_per_second(),
		"physics ms: %.1f" % Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"process ms: %.1f" % Performance.get_monitor(Performance.TIME_PROCESS),
		"draw calls: %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"wave window: %.1fs left" % _wave_window_timer.time_left,
		"next wave in: %.1fs" % _timer.time_left,
	])


# -------------------------
# WAVE SYSTEM
# -------------------------

func _on_wave_timer() -> void:
	# Sync real mob count before spawning
	active_mobs = get_tree().get_nodes_in_group(&"mob").size()

	for i in mobs_per_wave:
		spawn_queue.append(1)

	# Start the spawn window — queue clears after wave_spawn_window seconds
	_wave_window_timer.start(wave_spawn_window)
	_process_queue()
	# Next wave timer does NOT start here — it starts in _on_wave_window_closed


func _on_wave_window_closed() -> void:
	# Clear any unspawned mobs from this wave's queue
	if spawn_queue.size() > 0:
		spawn_queue.clear()
		_is_spawning = false  # reset in case coroutine was mid-await

	# Now schedule the next wave
	_schedule_next_wave()


func _schedule_next_wave() -> void:
	_timer.start(rng.randf_range(min_spawn_delay, max_spawn_delay))


# -------------------------
# SPAWN QUEUE — one mob per frame
# -------------------------

func _process_queue() -> void:
	if _is_spawning:
		return
	_is_spawning = true
	while spawn_queue.size() > 0 and active_mobs < MAX_MOBS:
		spawn_queue.pop_front()
		_spawn_mob()
		await get_tree().physics_frame
	_is_spawning = false


# -------------------------
# MOB SPAWNING
# -------------------------

func _spawn_mob() -> void:
	if mob_scene == null:
		return
	var mob := mob_scene.instantiate()
	mob.global_position = _get_valid_spawn_position()
	parent_node.add_child(mob)
	active_mobs += 1
	mob.tree_exiting.connect(_on_mob_removed)


func _on_mob_removed() -> void:
	active_mobs = max(active_mobs - 1, 0)
	_process_queue.call_deferred()


# -------------------------
# SPAWN POSITIONING
# -------------------------

func _get_valid_spawn_position() -> Vector3:
	var half := spawn_area_size * 0.5
	for i in max_attempts:
		var pos := Vector3(
			rng.randf_range(-half.x, half.x),
			spawn_height,
			rng.randf_range(-half.z, half.z)
		)
		var dx := pos.x - player_pos.x
		var dz := pos.z - player_pos.z
		if dx * dx + dz * dz >= min_dist_sq:
			return pos
	return Vector3(
		rng.randf_range(-half.x, half.x),
		spawn_height,
		rng.randf_range(-half.z, half.z)
	)

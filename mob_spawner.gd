extends Node3D

@export var mob_scene: PackedScene
@export var player_path: NodePath
@export var mobs_per_wave: int = 20
@export var min_spawn_delay: float = 40.0
@export var max_spawn_delay: float = 60.0
@export var spawn_area_size: Vector3 = Vector3(108, 0, 108)
@export var spawn_height: float = -0.5
@export var min_distance_from_player: float = 20.0
@export var max_attempts: int = 15
@export var wave_spawn_window: float = 20.0
@export var wave_spread_time: float = 5.0

const MAX_MOBS := 20

var active_mobs := 0
var spawn_queue: int = 0  # just a count, no array needed
var rng := RandomNumberGenerator.new()
var player: Node3D
var player_pos := Vector3.ZERO
var parent_node: Node3D
var _timer: Timer
var _wave_window_timer: Timer
var min_dist_sq: float
var _is_spawning := false
var debug_label: Label
var _debug_update_timer: float = 0.0  # only update label every 0.5s


func _ready() -> void:
	rng.randomize()
	player = get_node_or_null(player_path)
	parent_node = get_parent()
	min_dist_sq = min_distance_from_player * min_distance_from_player

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_wave_timer)

	_wave_window_timer = Timer.new()
	_wave_window_timer.one_shot = true
	add_child(_wave_window_timer)
	_wave_window_timer.timeout.connect(_on_wave_window_closed)

	call_deferred("_setup_debug_label")
	_on_wave_timer()


func _setup_debug_label() -> void:
	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.z_index = 100
	debug_label.modulate = Color.YELLOW
	get_viewport().add_child(debug_label)


func _process(delta: float) -> void:
	if is_instance_valid(player):
		player_pos = player.global_position

	# Only update debug label every 0.5s — not every frame
	if not is_instance_valid(debug_label):
		return
	_debug_update_timer -= delta
	if _debug_update_timer > 0.0:
		return
	_debug_update_timer = 0.5
	debug_label.text = "\n".join([
		"active_mobs: %d" % active_mobs,
		"queue: %d" % spawn_queue,
		"physics bodies: %d" % PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS),
		"fps: %d" % Engine.get_frames_per_second(),
		"physics ms: %.1f" % Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"process ms: %.1f" % Performance.get_monitor(Performance.TIME_PROCESS),
		"draw calls: %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"wave window: %.1fs" % _wave_window_timer.time_left,
		"next wave: %.1fs" % _timer.time_left,
	])


# -------------------------
# WAVE SYSTEM
# -------------------------

func _on_wave_timer() -> void:
	spawn_queue += mobs_per_wave
	_wave_window_timer.start(wave_spawn_window)
	if not _is_spawning:
		_process_queue()


func _on_wave_window_closed() -> void:
	spawn_queue = 0
	_is_spawning = false
	_schedule_next_wave()


func _schedule_next_wave() -> void:
	_timer.start(rng.randf_range(min_spawn_delay, max_spawn_delay))


# -------------------------
# SPAWN QUEUE — spread over wave_spread_time seconds
# -------------------------

func _process_queue() -> void:
	if _is_spawning:
		return
	_is_spawning = true

	var spawn_interval := wave_spread_time / maxf(mobs_per_wave, 1)

	while spawn_queue > 0 and active_mobs < MAX_MOBS:
		spawn_queue -= 1
		_spawn_mob()
		await get_tree().create_timer(spawn_interval).timeout

	_is_spawning = false


# -------------------------
# MOB SPAWNING
# -------------------------

func _spawn_mob() -> void:
	if mob_scene == null:
		return

	var spawn_pos := _get_valid_spawn_position()

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		spawn_pos + Vector3(0, 10, 0),
		spawn_pos + Vector3(0, -20, 0)
	)
	query.collision_mask = 1
	var result := space.intersect_ray(query)
	if not result:
		return  # no ground, skip — don't increment active_mobs

	spawn_pos = result.position + Vector3(0, 0.5, 0)

	var mob := mob_scene.instantiate()
	parent_node.add_child(mob)
	mob.global_position = spawn_pos
	active_mobs += 1
	mob.tree_exiting.connect(_on_mob_removed)


func _on_mob_removed() -> void:
	active_mobs = maxi(active_mobs - 1, 0)
	# Don't restart the spawn coroutine here — it runs on wave timer only
	# This prevents 20 simultaneous coroutines when a wave dies at once


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

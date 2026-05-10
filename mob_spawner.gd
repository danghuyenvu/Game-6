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

var rng := RandomNumberGenerator.new()
var player: Node3D
var _timer: Timer

func _ready():
	rng.randomize()
	player = get_node_or_null(player_path)

	# reuse one timer instead of creating many
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(spawn_wave)

	call_deferred("spawn_wave")
	_schedule_next_wave()


func _schedule_next_wave():
	_timer.start(rng.randf_range(min_spawn_delay, max_spawn_delay))


func spawn_wave():
	if not mob_scene:
		push_error("No mob scene assigned!")
		return

	# staggered spawning (prevents frame spikes)
	for i in mobs_per_wave:
		call_deferred("_spawn_mob")

	_schedule_next_wave()


func _spawn_mob():
	var mob = mob_scene.instantiate()
	get_parent().add_child(mob)
	mob.global_position = _get_valid_spawn_position()


func _get_valid_spawn_position() -> Vector3:
	var player_pos := player.global_position if is_instance_valid(player) else Vector3.ZERO

	var half_size := spawn_area_size * 0.5

	for i in max_attempts:
		var pos := Vector3(
			rng.randf_range(-half_size.x, half_size.x),
			spawn_height,
			rng.randf_range(-half_size.z, half_size.z)
		)

		if pos.distance_to(player_pos) >= min_distance_from_player:
			return pos

	# fallback (prevents infinite loop risk)
	return Vector3(
		rng.randf_range(-half_size.x, half_size.x),
		spawn_height,
		rng.randf_range(-half_size.z, half_size.z)
	)

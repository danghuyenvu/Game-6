extends CharacterBody3D

enum State {
	IDLE,
	CHASE,
	ATTACK,
	HURT,
	CRAWLING,
	DEAD,
}

const CLIPS := {
	State.IDLE: {"start": 0.0, "end": 10.0, "loop": true},
	State.CHASE: {"start": 10.0, "end": 11.0, "loop": true},
	State.HURT: {"start": 11.0, "end": 12.0, "loop": false},
	State.ATTACK: {"start": 12.0, "end": 14.0, "loop": false},
	State.CRAWLING: {"start": 19.0, "end": 20.0, "loop": true},
	State.DEAD: {"start": 20.0, "end": 23.0, "loop": false},
}

@export_group("Target")
@export var player_group: StringName = &"player"
@export var target_path: NodePath
@export var aggro_range: float = 40.0
@export var lose_aggro_range: float = 70.0
@export var attack_range: float = 1.1

@export_group("Movement")
@export var move_speed: float = 5.3
@export var crawl_speed: float = 1.6
@export var turn_speed: float = 18.0
@export var gravity_multiplier: float = 2.2
@export var step_height: float = 0.7

@export_group("Navigation")
@export var use_navigation: bool = true
@export var navigation_agent_path: NodePath = "NavigationAgent3D"

@export_group("Combat")
@export var max_health: float = 100.0
@export var attack_damage: float = 18.0
@export_range(0.0, 1.0, 0.01) var attack_hit_at: float = 0.45
@export var attack_cooldown: float = 1
@export var crawl_under_health_ratio: float = 0.35
@export var despawn_after_death: float = 8.0

@export_group("Animation")
@export var animation_player_path: NodePath
@export var animation_name: StringName
@export var debug_logs: bool = true


var target: Node3D
var state: State = State.IDLE:
	set(value):
		state = value
		_process_animation_state() # Hàm này có sẵn trong file của bạn để play anim

var health: float :
	set(value):
		health = value
		if health <= 0:
			state = State.DEAD
var _state_time: float = 0.0
var _attack_cooldown_left: float = 0.0
var _attack_has_hit := false
var _death_timer: float = 0.0
var _last_repath_time: float = 0.0

@onready var animation_player: AnimationPlayer = _resolve_animation_player()
@onready var navigation_agent: NavigationAgent3D = get_node_or_null(navigation_agent_path)

func _ready() -> void:
	health = max_health
	add_to_group(&"mob")
	_find_target()
	
	if use_navigation and not navigation_agent:
		navigation_agent = NavigationAgent3D.new()
		navigation_agent.name = "NavigationAgent3D"
		navigation_agent.radius = 0.6
		navigation_agent.height = 2.5
		navigation_agent.avoidance_enabled = true
		add_child(navigation_agent)
	
	print("MobNo1 Ready - Force Close Chase")
	_play_state(State.IDLE, true)


func _physics_process(delta: float) -> void:
	_process_animation_state()
	if not multiplayer.is_server():
		return
	if state == State.DEAD:
		_process_dead(delta)
		move_and_slide()
		return

	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	velocity += get_gravity() * gravity_multiplier * delta

	# Tìm target gần nhất mỗi frame nếu target hiện tại mất hoặc xa
	if not is_instance_valid(target) or global_position.distance_to(target.global_position) > lose_aggro_range:
		_find_target()

	_state_time += delta
	_update_state()

	match state:
		State.CHASE, State.CRAWLING:
			_chase_target(delta)
		State.ATTACK:
			_stop_horizontal_movement(delta)
			_face_target(delta)
		_:
			_stop_horizontal_movement(delta)

	move_and_slide()

	if is_on_floor() and velocity.y < 0:
		velocity.y = -0.5
	if is_on_wall():
		velocity.y = maxf(velocity.y, step_height * 6)


func _update_state() -> void:
	if state == State.HURT or state == State.ATTACK:
		if state == State.ATTACK:
			_process_attack_hit()
		return

	if not is_instance_valid(target):
		_play_state(State.IDLE)
		return

	var distance := global_position.distance_to(target.global_position)

	if distance > lose_aggro_range:
		target = null
		_play_state(State.IDLE)
		return

	# Chase mạnh mẽ
	if distance > attack_range * 1.0 and distance <= aggro_range:   # Cho phép chase sâu hơn
		if state not in [State.CHASE, State.CRAWLING]:
			_play_state(_move_state())
		return

	if distance <= attack_range and _attack_cooldown_left <= 0.0:
		if state != State.ATTACK:
			_play_state(State.ATTACK)
		return

	# Buộc chase khi còn khá gần
	if distance <= attack_range + 2.0:
		if state not in [State.CHASE, State.CRAWLING]:
			_play_state(_move_state())


func _chase_target(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var speed: float = crawl_speed if state == State.CRAWLING else move_speed
	var current_dist := global_position.distance_to(target.global_position)

	# Chỉ dừng khi đã vào sâu trong tầm attack
	if current_dist <= attack_range * 0.85:
		_stop_horizontal_movement(delta)
		return

	# Phần navigation / direct chase giữ nguyên như trước...
	if use_navigation and navigation_agent:
		navigation_agent.target_position = target.global_position
		var next_pos = navigation_agent.get_next_path_position()
		var direction = next_pos - global_position
		direction.y = 0.0
		
		if direction.length() < 0.5:
			_direct_chase(delta, speed)
			return
			
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		_face_direction(direction, delta)
	else:
		_direct_chase(delta, speed)

func _direct_chase(delta: float, speed: float) -> void:
	var direction = target.global_position - global_position
	direction.y = 0
	if direction.length() <= attack_range - 0.2:
		_stop_horizontal_movement(delta)
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face_direction(direction, delta)


func _stop_horizontal_movement(delta: float) -> void:
	var decel := move_speed * 15.0
	velocity.x = move_toward(velocity.x, 0, decel * delta)
	velocity.z = move_toward(velocity.z, 0, decel * delta)


func _face_target(delta: float) -> void:
	if not is_instance_valid(target): return
	var dir = target.global_position - global_position
	dir.y = 0
	if dir.length() > 0.3:
		_face_direction(dir.normalized(), delta)


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_yaw = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)


# ====================== Phần còn lại giữ nguyên ======================
func _play_state(next_state: State, force := false) -> void:
	if not force and state == next_state:
		return
	state = next_state
	_state_time = 0.0
	_attack_has_hit = state != State.ATTACK

	if debug_logs:
		print("=== STATE: ", State.keys()[state], " ===")

	if not animation_player: return
	var clip: Dictionary = CLIPS[state]
	animation_player.play(_animation_name())
	animation_player.seek(clip["start"], true)


# Các hàm animation, damage, die... giữ nguyên (copy từ file cũ của bạn)
func _process_animation_state() -> void:
	if not animation_player or not animation_player.is_playing():
		_process_unanimated_state()
		return
	var clip: Dictionary = CLIPS[state]
	if animation_player.current_animation_position < clip["end"]:
		return
	if clip["loop"]:
		animation_player.seek(clip["start"], true)
		return
	match state:
		State.ATTACK:
			_attack_cooldown_left = attack_cooldown
			_play_state(_move_state() if is_instance_valid(target) else State.IDLE)
		State.HURT:
			_play_state(_move_state() if is_instance_valid(target) else State.IDLE)
		State.DEAD:
			animation_player.pause()
			animation_player.seek(clip["end"], true)


func _process_unanimated_state() -> void:
	var clip: Dictionary = CLIPS[state]
	var duration: float = clip["end"] - clip["start"]
	if clip["loop"] or _state_time < duration:
		return
	match state:
		State.ATTACK:
			_attack_cooldown_left = attack_cooldown
			_play_state(_move_state() if is_instance_valid(target) else State.IDLE)
		State.HURT:
			_play_state(_move_state() if is_instance_valid(target) else State.IDLE)


func _process_attack_hit() -> void:
	if _attack_has_hit or not is_instance_valid(target):
		return
	var clip: Dictionary = CLIPS[State.ATTACK]
	var hit_time: float = lerpf(clip["start"], clip["end"], attack_hit_at)
	var current_time: float = animation_player.current_animation_position if animation_player else clip["start"] + _state_time
	if current_time < hit_time:
		return
	_attack_has_hit = true
	if global_position.distance_to(target.global_position) > attack_range + 0.8:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	elif target.has_method("damage"):
		target.damage(attack_damage)

@rpc("any_peer", "call_remote", "reliable")
func server_take_damage(amount: float):
	take_damage(amount) # Server nhận lệnh và trừ máu thật
	
func take_damage(amount: float) -> void:
	if not multiplayer.is_server():
		# Client bắn trúng thì gửi RPC lên Server
		server_take_damage.rpc_id(1, amount)
		return
	if state == State.DEAD: return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		_die()
	else:
		_play_state(State.HURT)


func damage(amount: float) -> void:
	take_damage(amount)


func _die() -> void:
	health = 0.0
	velocity = Vector3.ZERO
	_play_state(State.DEAD, true)
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true


func _process_dead(delta: float) -> void:
	_process_animation_state()
	_death_timer += delta
	if despawn_after_death > 0.0 and _death_timer >= despawn_after_death:
		queue_free()


func _move_state() -> State:
	if max_health > 0.0 and health / max_health <= crawl_under_health_ratio:
		return State.CRAWLING
	return State.CHASE


func _find_target() -> void:
	if not is_instance_valid(target):
		target = null
	
	# Ưu tiên target_path nếu có
	if not target_path.is_empty():
		var node = get_node_or_null(target_path)
		if node is Node3D:
			target = node
			return
	
	# Tìm tất cả player trong group
	var players = get_tree().get_nodes_in_group(player_group)
	if players.is_empty():
		# Fallback tìm ProtoController
		var scene = get_tree().current_scene
		if scene:
			var proto = scene.find_child("ProtoController", true, false)
			if proto is Node3D:
				target = proto
		return
	
	# Tìm player gần nhất
	var closest_player: Node3D = null
	var min_distance: float = INF
	
	for p in players:
		if p is Node3D and is_instance_valid(p):
			var dist = global_position.distance_to(p.global_position)
			if dist < min_distance:
				min_distance = dist
				closest_player = p
	
	if closest_player:
		target = closest_player
		if debug_logs:
			print("Mob selected closest player, distance = %.1f" % min_distance)


func _resolve_animation_player() -> AnimationPlayer:
	if not animation_player_path.is_empty():
		var node := get_node_or_null(animation_player_path)
		if node is AnimationPlayer:
			return node
	return _find_animation_player(self)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _animation_name() -> StringName:
	if animation_name != &"":
		return animation_name
	for candidate in animation_player.get_animation_list():
		if candidate != &"RESET":
			animation_name = candidate
			return candidate
	animation_name = &"RESET"
	return animation_name

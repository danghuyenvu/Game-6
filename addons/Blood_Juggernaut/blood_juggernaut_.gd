extends CharacterBody3D

# ================================================================
#  BOSS – BLOOD JUGGERNAUT
#
#  Single AnimationPlayer inside the Visual child (.blend import).
#  Animation tracks:
#    Armature_001|mixamo_com|Layer0  →  ROAR
#    Armature_002|mixamo_com|Layer0  →  LEAP  (first 3.5 s only)
#    Armature_003|mixamo_com|Layer0  →  IDLE  (loop)
#    Armature_004|mixamo_com|Layer0  →  RUN   (loop)
#    Armature_005|mixamo_com|Layer0  →  JUMP_IDLE (loop)
#    Armature|mixamo_com|Layer0      →  SLAM  (attack)
# ================================================================

enum State { IDLE, ROAR, CHASE, LEAP, JUMP_IDLE, ATTACK, HURT, DEAD }

const ANIM_TRACK := {
	State.ROAR:      "Armature_001|mixamo_com|Layer0",
	State.LEAP:      "Armature_002|mixamo_com|Layer0",
	State.IDLE:      "Armature_003|mixamo_com|Layer0",
	State.CHASE:     "Armature_004|mixamo_com|Layer0",
	State.JUMP_IDLE: "Armature_005|mixamo_com|Layer0",
	State.ATTACK:    "Armature|mixamo_com|Layer0",
	State.HURT:      "Armature_003|mixamo_com|Layer0",
	State.DEAD:      "Armature_003|mixamo_com|Layer0",
}

const ANIM_LOOP := {
	State.IDLE: true, State.CHASE: true, State.JUMP_IDLE: false,
	State.ROAR: false, State.LEAP: false, State.ATTACK: false,
	State.HURT: false, State.DEAD: false,
}

const LEAP_END_TIME := 3.5

# ── Exports ──────────────────────────────────────────────────
@export_group("Target")
@export var player_group:       StringName = &"player"
@export var aggro_range:        float = 50.0
@export var lose_aggro_range:   float = 80.0
@export var attack_range:       float = 2.5
@export var leap_min_range:     float = 8.0
@export var leap_max_range:     float = 20.0

@export_group("Movement")
@export var move_speed:         float = 6.5
@export var leap_speed:         float = 16.0
@export var leap_arc_height:    float = 6.0
@export var turn_speed:         float = 7.0
@export var gravity_multiplier: float = 2.2

@export_group("Navigation")
@export var use_navigation:     bool = true

@export_group("Combat")
@export var max_health:         float = 800.0
@export var attack_damage:      float = 45.0
@export_range(0.0, 1.0, 0.01) var attack_hit_at: float = 0.50
@export var attack_cooldown:    float = 2.2
@export var despawn_after_death: float = 10.0

@export_group("Debug")
@export var debug_logs: bool = true

# ── Runtime ──────────────────────────────────────────────────
var health:                float
var target:                Node3D
var state:                 State = State.IDLE
var _state_time:           float = 0.0
var _attack_cooldown_left: float = 0.0
var _attack_has_hit:       bool  = false
var _death_timer:          float = 0.0
var _has_roared:           bool  = false
var _leap_dir:             Vector3 = Vector3.ZERO

var _anim: AnimationPlayer
var _nav:  NavigationAgent3D


# ════════════════════════════════════════════════════════════
#  LIFECYCLE
# ════════════════════════════════════════════════════════════
func _ready() -> void:
	health = max_health
	add_to_group(&"boss")
	_anim = _find_anim_player(self)
	_nav  = get_node_or_null("NavigationAgent3D")
	_find_target()
	_play_state(State.IDLE, true)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_process_dead(delta)
		return

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * gravity_multiplier * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.5

	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_state_time += delta
	
	_refresh_target()
	_update_state()
	_tick_animation()

	# Nếu đang nhảy thì vẫn cập nhật hướng bay
	if state == State.LEAP and _leap_dir != Vector3.ZERO:
		velocity.x = _leap_dir.x * leap_speed
		velocity.z = _leap_dir.z * leap_speed

	_apply_movement(delta)
	move_and_slide()


# ════════════════════════════════════════════════════════════
#  STATE MACHINE
# ════════════════════════════════════════════════════════════
func _update_state() -> void:
	match state:
		State.ROAR, State.LEAP, State.HURT, State.JUMP_IDLE:
			return
		State.ATTACK:
			_process_attack_hit()
			return
	if not is_instance_valid(target):
		_play_state(State.IDLE)
		return

	var dist: float = _dist_to_target()

	if dist > lose_aggro_range:
		target = null
		_play_state(State.IDLE)
		return

	if dist <= aggro_range and not _has_roared:
		_has_roared = true
		_play_state(State.ROAR)
		return

	if dist <= attack_range and _attack_cooldown_left <= 0.0:
		_play_state(State.ATTACK)
		return

	if dist >= leap_min_range and dist <= leap_max_range and _attack_cooldown_left <= 0.0:
		_play_state(State.LEAP)
		return

	if dist > attack_range and dist <= aggro_range:
		if state != State.CHASE:
			_play_state(State.CHASE)
		return

	if dist <= attack_range + 2.0 and _attack_cooldown_left > 0.0:
		if state != State.JUMP_IDLE:
			_play_state(State.JUMP_IDLE)
		return


# ════════════════════════════════════════════════════════════
#  ANIMATION
# ════════════════════════════════════════════════════════════
func _play_state(next_state: State, force := false) -> void:
	if not force and state == next_state:
		return
	state = next_state
	_state_time = 0.0
	_attack_has_hit = (state != State.ATTACK)

	if debug_logs:
		print("[Juggernaut] >> ", State.keys()[state])

	if not _anim:
		return

	var track: String = ANIM_TRACK[state]
	if not _anim.has_animation(track):
		if debug_logs:
			push_warning("[Juggernaut] Missing track: " + track)
		return

	_anim.play(track)

	if state == State.LEAP and is_instance_valid(target):
		var dir := target.global_position - global_position
		dir.y = 0.0
		var dist := dir.length()
		_leap_dir = dir.normalized()

	# Tính thời gian bay dựa trên animation
		var t := LEAP_END_TIME

	# Tính velocity ngang để vừa tới target
		var vx := dir.x / t
		var vz := dir.z / t

	# Tính velocity dọc để tạo cung parabol
		var vy := (target.global_position.y - global_position.y) / t + leap_arc_height

		velocity = Vector3(vx, vy, vz)


func _tick_animation() -> void:
	if not _anim or not _anim.is_playing():
		_on_clip_finished()
		return

	if state == State.LEAP and _anim.current_animation_position >= LEAP_END_TIME:
		_anim.stop()
		_on_clip_finished()
		return

	if ANIM_LOOP.get(state, false):
		if _anim.current_animation_position >= _anim.current_animation_length - 0.05:
			_anim.seek(0.0, true)


func _on_clip_finished() -> void:
	match state:
		State.ROAR:
			_play_state(State.CHASE if is_instance_valid(target) else State.IDLE)
		State.LEAP:
			_leap_dir = Vector3.ZERO
# Snap boss về gần target để tránh lệch collision
			if is_instance_valid(target):
				global_position.x = target.global_position.x + (target.global_position.x - global_position.x)
				global_position.z = target.global_position.z + (target.global_position.z - global_position.z)
			_play_state(State.ATTACK if _dist_to_target() <= attack_range + 1.5 else State.CHASE)
		State.ATTACK:
			_attack_cooldown_left = attack_cooldown
			_play_state(State.CHASE if is_instance_valid(target) else State.IDLE)
		State.HURT:
			_play_state(State.CHASE if is_instance_valid(target) else State.IDLE)
		State.JUMP_IDLE:
			# Khi animation Jump Idle kết thúc thì thoát ra
			_play_state(State.CHASE if is_instance_valid(target) else State.IDLE)
		State.DEAD:
			if _anim:
				_anim.stop()


# ════════════════════════════════════════════════════════════
#  MOVEMENT
# ════════════════════════════════════════════════════════════
func _apply_movement(delta: float) -> void:
	match state:
		State.CHASE:
			_move_toward_target(delta)
		State.LEAP:
			var flat := velocity
			flat.y = 0.0
			if flat.length_squared() > 0.01:
				_face_direction(flat.normalized(), delta)
		State.ATTACK, State.ROAR:
			_face_target(delta)
			velocity.x = 0.0
			velocity.z = 0.0
		State.JUMP_IDLE, State.IDLE:
			_face_target(delta)
			velocity = Vector3.ZERO
		_:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * 10.0 * delta)

func _move_toward_target(delta: float) -> void:
	if not is_instance_valid(target):
		return
	if _dist_to_target() <= attack_range * 0.85:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 10.0 * delta)
		return

	var direction: Vector3
	if use_navigation and _nav and not _nav.is_navigation_finished():
		_nav.target_position = target.global_position
		var next := _nav.get_next_path_position()
		direction = next - global_position
		direction.y = 0.0
		if direction.length() < 0.5:
			direction = target.global_position - global_position
			direction.y = 0.0
	else:
		direction = target.global_position - global_position
		direction.y = 0.0

	if direction.length_squared() < 0.01:
		return

	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face_direction(direction, delta)


func _face_target(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dir := target.global_position - global_position
	dir.y = 0.0
	if dir.length() > 0.2:
		_face_direction(dir.normalized(), delta)


func _face_direction(dir: Vector3, delta: float) -> void:
	var yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, turn_speed * delta)


# ════════════════════════════════════════════════════════════
#  COMBAT
# ════════════════════════════════════════════════════════════
func _process_attack_hit() -> void:
	if _attack_has_hit or not is_instance_valid(target) or not _anim:
		return
	var hit_time := _anim.current_animation_length * attack_hit_at
	if _anim.current_animation_position < hit_time:
		return
	_attack_has_hit = true
	if _dist_to_target() > attack_range + 1.2:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	elif target.has_method("damage"):
		target.damage(attack_damage)


func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	health = maxf(health - amount, 0.0)
	if debug_logs:
		print("[Juggernaut] HP %.0f / %.0f" % [health, max_health])
	if health <= 0.0:
		_die()
	else:
		_play_state(State.HURT)


func damage(amount: float) -> void:
	take_damage(amount)


func _die() -> void:
	health = 0.0
	_play_state(State.DEAD, true)
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true


func _process_dead(delta: float) -> void:
	_tick_animation()
	_death_timer += delta
	if despawn_after_death > 0.0 and _death_timer >= despawn_after_death:
		queue_free()


# ════════════════════════════════════════════════════════════
#  HELPERS
# ════════════════════════════════════════════════════════════
func _dist_to_target() -> float:
	if not is_instance_valid(target):
		return INF
	return global_position.distance_to(target.global_position)


func _refresh_target() -> void:
	if is_instance_valid(target) and _dist_to_target() <= lose_aggro_range:
		return
	target = null
	_find_target()


func _find_target() -> void:
	var players := get_tree().get_nodes_in_group(player_group)
	var closest: Node3D = null
	var min_dist := INF
	for p in players:
		if p is Node3D and is_instance_valid(p):
			var d := global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest = p
	if closest:
		target = closest
		if debug_logs:
			print("[Juggernaut] Target locked, dist=%.1f" % min_dist)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

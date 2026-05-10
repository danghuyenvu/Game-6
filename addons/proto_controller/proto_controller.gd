# ProtoController v1.0 by Brackeys (Multiplayer patch)
extends CharacterBody3D

@export var can_move : bool = true
@export var has_gravity : bool = true
@export var can_jump : bool = true
@export var can_sprint : bool = true
@export var can_freefly : bool = false

@export_group("Speeds")
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 3.0
## Speed of jump.
@export var jump_velocity : float = 4.0
## How fast do we run?
@export var sprint_speed : float = 7.5
@export var freefly_speed : float = 25.0

@export_group("Input Actions")
@export var input_left : String = "ui_left"
@export var input_right : String = "ui_right"
@export var input_forward : String = "ui_up"
@export var input_back : String = "ui_down"
@export var input_jump : String = "ui_accept"
@export var input_sprint : String = "sprint"
@export var input_freefly : String = "freefly"

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var weapon_manager = $Head/Camera3D/WeaponManager
@onready var crosshair = $CanvasLayer/Crosshair
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

@export var air_accel := 3.0
@export var ground_accel := 2.0
@export var auto_jump := true

var jump_held := false
var nearby_items: Array = []
var nearby_shop: Node = null
var _authority_applied: bool = false

func grab_item(item) -> void:
	item.apply_effect(self)

func _ready() -> void:
	var peer_id = name.to_int() 
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
	
	check_input_mappings()
	if multiplayer.has_multiplayer_peer():
		_setup_authority()
	#check_input_mappings()
	#look_rotation.y = rotation.y
	#look_rotation.x = head.rotation.x
	## Defer so set_multiplayer_authority() from game.gd is guaranteed to have run
	#call_deferred("_setup_authority")

func apply_authority():
	_authority_applied = false  # reset flag để apply_authority có thể chạy lại
	_setup_authority()
	print("apply_authority | my id: ", multiplayer.get_unique_id(), " | authority: ", get_multiplayer_authority(), " | is_auth: ", is_multiplayer_authority())
	if is_multiplayer_authority():
		capture_mouse()
		$Head/Camera3D.current = true
		$CanvasLayer.visible = true
		set_physics_process(true)
	else:
		$Head/Camera3D.current = false
		$CanvasLayer.visible = false
		set_physics_process(false)

func _setup_authority():
	print("_setup_authority | my id: ", multiplayer.get_unique_id(), " | authority: ", get_multiplayer_authority(), " | is_auth: ", is_multiplayer_authority())
	#if _authority_applied:
		#return
	#_authority_applied = true
	#if is_multiplayer_authority():
		#capture_mouse()
		#$Head/Camera3D.current = true
		#$CanvasLayer.visible = true
		#set_physics_process(true)
	#else:
		#$Head/Camera3D.current = false
		#$CanvasLayer.visible = false
		#set_physics_process(false)
	var is_auth = is_multiplayer_authority()
	set_physics_process(is_auth)
	set_process_unhandled_input(is_auth) # Đảm bảo input được bật/tắt đúng
	
	if is_auth:
		capture_mouse()
		$Head/Camera3D.current = true
		$CanvasLayer.visible = true
	else:
		$Head/Camera3D.current = false
		$CanvasLayer.visible = false

# ─── RPCs ────────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "unreliable_ordered")
func sync_head_pitch(pitch: float):
	if not is_multiplayer_authority():
		head.rotation.x = pitch

@rpc("any_peer", "call_remote", "reliable")
func request_shoot():
	if not multiplayer.is_server(): return
	print("pass this ")
	# Server thực hiện bắn trên instance của Player này tại Server
	action_shoot()
	
	# Báo cho các máy khác (Player 1, Player 3...) thấy Player 2 bắn
	confirm_shoot.rpc()
	
	
func action_shoot():
	if weapon_manager:
		var weapon = weapon_manager.get_current_weapon()
		if weapon:
			weapon.shoot()
# Thành:
@rpc("call_remote", "reliable")
func confirm_shoot():
	# Không chạy lại trên máy người đã bắn (vì đã chạy ở bước 1)
	if is_multiplayer_authority(): return
	action_shoot()

@rpc("any_peer", "call_remote", "reliable")
func request_grab(item_path: NodePath):
	if not multiplayer.is_server(): return
	var item = get_node_or_null(item_path)
	if item: grab_item(item)

# ─── Input ───────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()

	if Input.is_action_just_pressed("shoot"):
		# 1. Bắn ngay lập tức trên máy mình (Client-side Prediction)
		action_shoot()
		# 2. Gửi lệnh lên Server để xử lý thực tế
		request_shoot.rpc()
		#if multiplayer.is_server():
			#request_shoot()
		#else:
			#request_shoot.rpc_id(1)
	if Input.is_action_just_pressed("reload"):
		var weapon = weapon_manager.get_current_weapon()
		if weapon:
			weapon.reload()
	# interact — only handle once (removed duplicate block)
	if Input.is_action_just_pressed("interact"):
		if nearby_shop != null:
			nearby_shop.open_menu()
		elif nearby_items.size() > 0:
			if multiplayer.is_server():
				request_grab(nearby_items[0].get_path())
			else:
				request_grab.rpc_id(1, nearby_items[0].get_path())

	if Input.is_key_pressed(KEY_1):
		weapon_manager.equip_primary()
	if Input.is_key_pressed(KEY_2):
		weapon_manager.equip_secondary()
		
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)

	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

# ─── Physics ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return

	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return

	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta

	if can_jump:
		if auto_jump and jump_held and is_on_floor():
			velocity.y = jump_velocity
		elif Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity

	if can_sprint and Input.is_action_pressed(input_sprint):
		move_speed = sprint_speed
	else:
		move_speed = base_speed


	# ----------------------------
	# STRAFE BHOP MOVEMENT (FIXED)
	# ----------------------------
	if can_move:

		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var wish_dir := (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		var horizontal_vel := Vector3(velocity.x, 0, velocity.z)

		# ----------------------------
		# GROUND MOVEMENT (tight FPS feel)
		# ----------------------------
		if is_on_floor():

			if wish_dir != Vector3.ZERO:
				var target = wish_dir * move_speed

				# direct acceleration (no smoothing / no lerp)
				horizontal_vel = horizontal_vel.move_toward(target, ground_accel * delta * 20.0)

			else:
				# strong friction (THIS fixes sliding)
				horizontal_vel = horizontal_vel.move_toward(Vector3.ZERO, ground_accel * delta * 25.0)

		# ----------------------------
		# AIR MOVEMENT (STRONGER STRAFE SPEED GAIN)
		# ----------------------------
		else:
	
			if wish_dir != Vector3.ZERO:

				var horizontal_speed: float = horizontal_vel.length()

				var vel_dir: Vector3 = horizontal_vel.normalized() if horizontal_speed > 0.001 else Vector3.ZERO

				var alignment: float = vel_dir.dot(wish_dir)

				# stronger base accel
				var accel: float = air_accel * delta * 2.0

				# STRAFE BOOST (more aggressive than before)
				var strafe_factor: float = 1.0 + pow(max(0.0, -alignment), 1.5) * 15

				var target_speed: float = move_speed

				var current_along_dir: float = horizontal_vel.dot(wish_dir)
				var speed_diff: float = target_speed - current_along_dir

				if speed_diff > 0.0:
					var add_speed: float = min(accel * strafe_factor, speed_diff)
					horizontal_vel += wish_dir * add_speed

		# apply back
		velocity.x = horizontal_vel.x
		velocity.z = horizontal_vel.z
	if is_multiplayer_authority():
		crosshair.set_moving(velocity.length() > 0.1)
	
	# Use velocity to actually move
	move_and_slide()

# ─── Look ────────────────────────────────────────────────────────────────────

func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)
	sync_head_pitch.rpc(head.rotation.x)

# ─── Helpers ─────────────────────────────────────────────────────────────────


func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false

# ----------------------------
# PLAYER HEALTH
# ----------------------------
@export var max_health := 100
var health := 100

@onready var hud = $CanvasLayer/HUD


func take_damage(amount: int):
	health -= amount
	health = clamp(health, 0, max_health)

	# Update HUD
	if hud and hud.has_method("update_health"):
		hud.update_health(health)

	# Death
	if health <= 0:
		die()


func heal(amount: int):
	health += amount
	health = clamp(health, 0, max_health)

	if hud and hud.has_method("update_health"):
		hud.update_health(health)


func die():
	print("Player died")

	# disable movement
	can_move = false
	can_jump = false
	can_sprint = false

	# optional reset/reload
	get_tree().reload_current_scene()
	
func refill_ammo(ammo_type):
	weapon_manager.primary_weapon.refill(ammo_type)
	weapon_manager.secondary_weapon.refill(ammo_type)


func _on_area_3d_body_entered(body: Node3D) -> void:
	pass # Replace with function body.

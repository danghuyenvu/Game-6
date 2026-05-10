# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = true
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 3.0
## Speed of jump.
@export var jump_velocity : float = 4.0
## How fast do we run?
@export var sprint_speed : float = 7.5
## How fast do we freefly?
@export var freefly_speed : float = 25.0

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var weapon_manager = $Head/Camera3D/WeaponManager
@onready var crosshair = $CanvasLayer/Crosshair

@export var air_accel := 3.0
@export var ground_accel := 2.0
@export var auto_jump := true

var jump_held := false

func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SPACE:
			jump_held = event.pressed
			
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()

	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	# Mouse capturing
	if Input.is_action_just_pressed("shoot"):
		var weapon = weapon_manager.get_current_weapon()
		if weapon:
			weapon.shoot()

	if Input.is_action_just_pressed("reload"):
		var weapon = weapon_manager.get_current_weapon()
		if weapon:
			weapon.reload()
			
	if Input.is_key_pressed(KEY_1):
		weapon_manager.equip_primary()

	if Input.is_key_pressed(KEY_2):
		weapon_manager.equip_secondary()
	
	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta

	# Apply jumping (AUTO JUMP FIXED)
	if can_jump:
		if auto_jump and jump_held and is_on_floor():
			velocity.y = jump_velocity
		elif Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity

	# sprint speed
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
	
	crosshair.set_moving(velocity.length() > 0.1)
	
	# Use velocity to actually move
	move_and_slide()


## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


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


## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
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

extends Node3D
class_name WeaponBase

# ----------------------------
# STATE
# ----------------------------
var can_shoot := true
var reloading := false
var equipped := false

# ----------------------------
# STATS
# ----------------------------
@export var weapon_id := "base"
@export var weapon_damage := 15
@export var weapon_range := 100.0


var crosshair


func _ready():
	crosshair = get_tree().get_first_node_in_group("crosshair")

# ----------------------------
# EQUIP SYSTEM
# ----------------------------
func equip():
	equipped = true
	visible = true


func unequip():
	equipped = false
	visible = false


# ----------------------------
# SHOOT ENTRY (override in child OR use this)
# ----------------------------
func shoot():
	if not equipped:
		return

	if not can_shoot or reloading:
		return

	can_shoot = false

	hitscan_shoot()

	await get_tree().create_timer(get_fire_rate()).timeout
	can_shoot = true


func get_fire_rate():
	return 0.15


# ----------------------------
# HITSCAN CORE
# ----------------------------
func hitscan_shoot():
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return

	var origin = camera.global_transform.origin
	var direction = get_shot_direction(camera)

	var target = origin + direction * weapon_range

	var space_state = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result = space_state.intersect_ray(query)

	if result:
		apply_hit(result)


# ----------------------------
# ACCURACY SYSTEM
# ----------------------------
func get_spread():
	if crosshair:
		return crosshair.get_spread()

	return 0.01


func get_shot_direction(camera):
	var forward = -camera.global_transform.basis.z
	var right = camera.global_transform.basis.x
	var up = camera.global_transform.basis.y

	var spread = get_spread()

	forward += right * randf_range(-spread, spread)
	forward += up * randf_range(-spread, spread)

	return forward.normalized()


# ----------------------------
# DAMAGE SYSTEM
# ----------------------------
func apply_hit(result):
	var target = result.collider

	if target.has_method("take_damage"):
		target.take_damage(weapon_damage)

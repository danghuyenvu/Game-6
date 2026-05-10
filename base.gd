extends WeaponBase

@onready var anim = $AnimationPlayer
@onready var hud = get_node("/root/Node3D/ProtoController/CanvasLayer/HUD")

const MAG_SIZE := 15
const FIRE_RATE := 0.15

var current_ammo := MAG_SIZE


# ----------------------------
# SHOOT
# ----------------------------
func shoot():
	if not equipped:
		return

	if not can_shoot or reloading:
		return

	if current_ammo <= 0:
		return

	can_shoot = false
	current_ammo -= 1

	on_shoot()

	hitscan_shoot()

	update_hud()

	await get_tree().create_timer(FIRE_RATE).timeout
	can_shoot = true


# ----------------------------
# RELOAD
# ----------------------------
func reload():
	if reloading:
		return

	if current_ammo == MAG_SIZE:
		return

	reloading = true

	if anim:
		anim.play("reload")

	await anim.animation_finished

	current_ammo = MAG_SIZE
	reloading = false

	update_hud()


# ----------------------------
# ANIMATION HOOK
# ----------------------------
func on_shoot():
	if anim:
		anim.play("shoot")


# ----------------------------
# SPREAD (NOW CONNECTED TO CROSSHAIR)
# ----------------------------
func get_spread():
	return super.get_spread()


# ----------------------------
# HIT LOGIC (FIXED DAMAGE SYSTEM)
# ----------------------------
func apply_hit(result):
	var target = result.collider

	if target.has_method("take_damage"):
		target.take_damage(weapon_damage)


# ----------------------------
# HUD UPDATE (FIXED)
# ----------------------------
func update_hud():
	if hud:
		hud.update_ammo(current_ammo, MAG_SIZE)

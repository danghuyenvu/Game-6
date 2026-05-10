extends WeaponBase
class_name PumpShotgun

@onready var anim = $AnimationPlayer
@onready var hud = get_node("/root/Node3D/ProtoController/CanvasLayer/HUD")

const MAG_SIZE := 10
const MAX_RESERVE := 60
const FIRE_RATE := 0.35
const PELLETS := 8

var current_ammo := MAG_SIZE
var reserve_ammo := MAX_RESERVE

var reload_cancelled := false
var reload_active := false


func _ready():
	weapon_id = "pump"
	weapon_damage = 20
	weapon_range = 300


# ----------------------------
# SHOOT
# ----------------------------
func shoot():
	if not equipped:
		return

	if reloading:
		cancel_reload()
		return

	if not can_shoot:
		return

	if current_ammo <= 0:
		return

	can_shoot = false
	current_ammo -= 1

	if anim:
		anim.stop()
		anim.play("shoot")

	for i in range(PELLETS):
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

	if reserve_ammo <= 0:
		return

	reloading = true
	reload_active = true
	reload_cancelled = false
	can_shoot = false

	if anim:
		anim.play("reload")

	await get_tree().create_timer(0.2).timeout

	while current_ammo < MAG_SIZE and reserve_ammo > 0:

		if reload_cancelled:
			break

		current_ammo += 1
		reserve_ammo -= 1
		update_hud()

		# 🔥 FULL MAG CHECK (IMPORTANT FIX)
		if current_ammo >= MAG_SIZE:
			_fast_finish_reload()
			return

		await get_tree().create_timer(0.3).timeout

	_finish_reload()


# ----------------------------
# CANCEL RELOAD
# ----------------------------
func cancel_reload():
	if not reloading:
		return

	reload_cancelled = true
	_fast_finish_reload()


# ----------------------------
# FAST FINISH (shared logic)
# ----------------------------
func _fast_finish_reload():
	if anim:
		var length = anim.current_animation_length
		anim.seek(max(length - 0.3, 0.0), true)

	await get_tree().create_timer(0.3).timeout
	_finish_reload()


# ----------------------------
# END STATE
# ----------------------------
func _finish_reload():
	reload_active = false
	reloading = false
	can_shoot = true
	update_hud()


# ----------------------------
# DAMAGE
# ----------------------------
func apply_hit(result):
	var target = result.collider

	if target and target.has_method("take_damage"):
		target.take_damage(weapon_damage)


# ----------------------------
# HUD
# ----------------------------
func update_hud():
	if hud:
		hud.update_ammo(current_ammo, reserve_ammo)


# ----------------------------
# SPREAD
# ----------------------------
func get_spread():
	return super.get_spread() * 2.5

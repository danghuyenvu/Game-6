extends WeaponBase

@onready var anim = $AnimationPlayer
@onready var hud = get_node("/root/Node3D/ProtoController/CanvasLayer/HUD")

const MAG_SIZE := 15
const MAX_RESERVE := 75
const FIRE_RATE := 0.75

var current_ammo := MAG_SIZE
var reserve_ammo := MAX_RESERVE


func _ready():
	weapon_id = "marksman"
	weapon_damage = 100
	weapon_range = 500

	call_deferred("update_hud")


# ----------------------------
# EQUIP / UNEQUIP
# ----------------------------
func equip():
	super.equip()
	update_hud()


func unequip():
	super.unequip()


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

	if anim:
		anim.play("shoot")

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

	if anim:
		anim.play("reload")

	await anim.animation_finished

	var needed = MAG_SIZE - current_ammo
	var to_load = min(needed, reserve_ammo)

	current_ammo += to_load
	reserve_ammo -= to_load

	reloading = false
	update_hud()


# ----------------------------
# SPREAD (marksman = tighter accuracy)
# ----------------------------
func get_spread():
	return super.get_spread() * 0.5


# ----------------------------
# HIT LOGIC (uses 100 damage)
# ----------------------------
func apply_hit(result):
	var target = result.collider

	if target.has_method("take_damage"):
		target.take_damage(weapon_damage)


# ----------------------------
# HUD
# ----------------------------
func update_hud():
	if hud:
		hud.update_ammo(current_ammo, reserve_ammo)

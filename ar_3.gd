extends WeaponBase

@onready var anim = $AnimationPlayer
@onready var hud = get_node("/root/Node3D/ProtoController/CanvasLayer/HUD")

const MAG_SIZE := 30
const MAX_RESERVE := 90
const FIRE_RATE := 0.3
const BURST_COUNT := 3
const BURST_DELAY := 0.06

var current_ammo := MAG_SIZE
var reserve_ammo := MAX_RESERVE


func _ready():
	weapon_id = "aug"
	weapon_damage = 20
	weapon_range = 375

	call_deferred("update_hud")


func equip():
	super.equip()
	update_hud()


func unequip():
	super.unequip()


func shoot():
	if not equipped:
		return

	if not can_shoot or reloading:
		return

	if current_ammo <= 0:
		return

	can_shoot = false

	for i in BURST_COUNT:
		if current_ammo <= 0:
			break

		current_ammo -= 1

		if anim:
			anim.stop()
			anim.play("shoot")

		hitscan_shoot()
		update_hud()

		if i < BURST_COUNT - 1:
			await get_tree().create_timer(BURST_DELAY).timeout

	await get_tree().create_timer(FIRE_RATE).timeout
	can_shoot = true


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


func get_spread():
	return super.get_spread() * 0.55


func apply_hit(result):
	var target = result.collider

	if target.has_method("take_damage"):
		target.take_damage(weapon_damage)


func update_hud():
	if hud:
		hud.update_ammo(current_ammo, reserve_ammo)

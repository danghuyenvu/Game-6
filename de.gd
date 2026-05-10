extends WeaponBase
class_name Magnum

@onready var anim = $AnimationPlayer
@onready var hud = get_node("/root/Node3D/ProtoController/CanvasLayer/HUD")

const MAG_SIZE := 8
const FIRE_RATE := 0.35
const DAMAGE := 40

var current_ammo := MAG_SIZE


func _ready():
	weapon_id = "magnum"
	weapon_damage = DAMAGE
	weapon_range = 150

	call_deferred("update_hud")


# ----------------------------
# SHOOT
# ----------------------------
func shoot():
	if not can_shoot or reloading:
		return

	if current_ammo <= 0:
		return

	can_shoot = false
	current_ammo -= 1

	if anim:
		anim.play("shoot")

	# 🔥 hitscan shot
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
# HIT LOGIC
# ----------------------------
func apply_hit(result):
	var target = result.collider

	if target and target.has_method("take_damage"):
		target.take_damage(DAMAGE)


# ----------------------------
# HUD
# ----------------------------
func update_hud():
	if hud:
		hud.update_ammo(current_ammo, -1)

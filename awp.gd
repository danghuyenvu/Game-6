extends Node3D

@onready var anim = $AnimationPlayer

const MAG_SIZE = 10
const MAX_RESERVE = 50
const FIRE_RATE = 0.95

var current_ammo = MAG_SIZE
var reserve_ammo = MAX_RESERVE
var can_shoot = true
var reloading = false

func _input(event):
	if Input.is_action_just_pressed("shoot"):
		shoot()

	if Input.is_action_just_pressed("reload"):
		reload()

func shoot():
	if not can_shoot or reloading:
		return

	if current_ammo <= 0:
		print("Empty mag")
		return

	current_ammo -= 1
	can_shoot = false

	anim.play("shoot")

	print("Bang")
	print("Ammo: ", current_ammo, "/", reserve_ammo)

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
	anim.play("reload")

	await anim.animation_finished

	var needed = MAG_SIZE - current_ammo
	var to_load = min(needed, reserve_ammo)

	current_ammo += to_load
	reserve_ammo -= to_load

	reloading = false

	print("Reloaded")
	print("Ammo: ", current_ammo, "/", reserve_ammo)

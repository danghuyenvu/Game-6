extends Control

@onready var top = $Top
@onready var bottom = $Bottom
@onready var left = $Left
@onready var right = $Right

var current_gap = 6.0
var target_gap = 6.0
var expand_speed = 12.0

var weapon_profiles = {
	"awp": {
		"idle_gap": 4.0,
		"move_gap": 10.0
	},
	"smg": {
		"idle_gap": 8.0,
		"move_gap": 20.0
	},
	"shotgun": {
		"idle_gap": 12.0,
		"move_gap": 28.0
	}
}

var current_weapon = "awp"

func _process(delta):
	current_gap = lerp(current_gap, target_gap, expand_speed * delta)
	update_crosshair()

func update_crosshair():
	top.position = Vector2(-1, -current_gap - 10)
	bottom.position = Vector2(-1, current_gap)

	left.position = Vector2(-current_gap - 10, -1)
	right.position = Vector2(current_gap, -1)

func set_weapon(weapon_name):
	if weapon_profiles.has(weapon_name):
		current_weapon = weapon_name

func set_moving(moving):
	var profile = weapon_profiles[current_weapon]

	if moving:
		target_gap = profile.move_gap
	else:
		target_gap = profile.idle_gap

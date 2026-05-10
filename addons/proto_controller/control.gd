extends Control

@onready var top = $Top
@onready var bottom = $Bottom
@onready var left = $Left
@onready var right = $Right

var current_gap := 6.0
var target_gap := 6.0
var expand_speed := 12.0

var weapon_profiles = {
	"awp": {
		"idle_gap": 2.0,
		"move_gap": 8.0
	},
	"marksman": {
		"idle_gap": 3.0,
		"move_gap": 6.0
	},
	"base": {
		"idle_gap": 6.0,
		"move_gap": 12.0
	},
	"pistol": {
		"idle_gap": 5.0,
		"move_gap": 14.0
	},
	"magnum": {
		"idle_gap": 4.0,
		"move_gap": 16.0
	},
	"revolver": {
		"idle_gap": 5.0,
		"move_gap": 17.0
	},
	"doublebarrel": {
		"idle_gap": 20.0,
		"move_gap": 40.0
	}
}

var current_weapon_id := "base"

func _ready():
	add_to_group("crosshair")

func _process(delta):
	current_gap = lerp(current_gap, target_gap, expand_speed * delta)
	update_crosshair()


func update_crosshair():
	top.position = Vector2(-1, -current_gap - 10)
	bottom.position = Vector2(-1, current_gap)
	left.position = Vector2(-current_gap - 10, -1)
	right.position = Vector2(current_gap, -1)


# NEW: called by WeaponManager
func set_weapon(weapon: WeaponBase):
	if weapon == null:
		return

	var weapon_id = weapon.weapon_id

	if weapon_profiles.has(weapon_id):
		current_weapon_id = weapon_id

		var profile = weapon_profiles[current_weapon_id]

		target_gap = profile.idle_gap
		current_gap = target_gap


func set_moving(moving: bool):
	if not weapon_profiles.has(current_weapon_id):
		return

	var profile = weapon_profiles[current_weapon_id]

	if moving:
		target_gap = profile.move_gap
	else:
		target_gap = profile.idle_gap

func get_spread() -> float:
	# normalize gap into usable weapon spread
	# tweak divisor to taste
	return current_gap * 0.002

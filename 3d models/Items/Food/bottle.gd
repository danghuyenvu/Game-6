extends Node3D

# Spin speed
@export var spin_speed: float = 90.0   # degrees per second
# Levitation amplitude
@export var levitate_height: float = 0.15
@export var levitate_speed: float = 2.0

# Item attributes
@export_enum("bottle", "burger", "hotdog", "icecream", "ketchup", "mayo", "sandwichfull", "sausage", "sauce") var item_type: String
@export_range(0, 100, 20) var hunger_value: int = 20

var base_y: float

func _process(delta: float):
	# Spin
	rotate_y(deg_to_rad(spin_speed * delta))
	
	# Levitate
	var pos = global_transform.origin
	pos.y = base_y + sin(Time.get_ticks_msec() / 1000.0 * levitate_speed) * levitate_height
	global_transform.origin = pos

@onready var prompt_label3d = $PromptLabel3D

func _ready():
	base_y = global_transform.origin.y
	prompt_label3d.visible = false

func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		prompt_label3d.visible = true
		body.nearby_items.append(self)

func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		prompt_label3d.visible = false
		body.nearby_items.erase(self)
		
func apply_effect(body):
	# apply effects to player here
	pass

extends Node3D

# Spin speed
@export var spin_speed: float = 90.0   # degrees per second
# Levitation amplitude
@export var levitate_height: float = 0.15
@export var levitate_speed: float = 2.0

# Item attributes
@export_enum("bottle", "burger", "hotdog", "icecream", "ketchup", "mayo", "sandwichfull", "sausage", "sauce") var item_type: String

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
	var heal_amount = 0
	match item_type:
		"bottle":
			heal_amount = 10
		"burger":
			heal_amount = 70
		"hotdog":
			heal_amount = 50
		"icecream":
			heal_amount = 10
		"ketchup":
			heal_amount = 20
		"mayo":
			heal_amount = 15
		"sandwichfull":
			heal_amount = 90
		"sausage":
			heal_amount = 30
		"sauce":
			heal_amount = 5
		_:
			heal_amount = 0
	if body.has_method("heal"):
		body.heal(heal_amount)
	# after done, self destruct
	self.queue_free()
	pass

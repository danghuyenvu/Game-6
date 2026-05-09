extends Node3D

# Spin speed
@export var spin_speed: float = 90.0   # degrees per second
# Levitation amplitude
@export var levitate_height: float = 0.15
@export var levitate_speed: float = 2.0

var base_y: float

func _ready():
	base_y = global_transform.origin.y

func _process(delta: float):
	# Spin
	rotate_y(deg_to_rad(spin_speed * delta))
	
	# Levitate
	var pos = global_transform.origin
	pos.y = base_y + sin(Time.get_ticks_msec() / 1000.0 * levitate_speed) * levitate_height
	global_transform.origin = pos

func _on_area_body_entered(body):
	if body.is_in_group("player"):
		queue_free()  # simulate grab/collect
		# perform some grabbing logic here
		

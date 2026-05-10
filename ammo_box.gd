extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.nearby_shop = self
	pass # Replace with function body.


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.nearby_shop = null
	pass # Replace with function body.

func open_menu():
	# open menu logic, here for ammo box gonna refill ammo
	pass

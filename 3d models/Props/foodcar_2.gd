extends Node3D

@onready var prompt_label3d = $PromptLabel3D

func _ready():
	prompt_label3d.visible = false

func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		prompt_label3d.visible = true
		print("added")
		body.nearby_shop = self

func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		prompt_label3d.visible = false
		body.nearby_items.erase(self)
		body.nearby_shop = null
		
func open_menu():
	# apply effects to player here
	print("Menu shown")
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

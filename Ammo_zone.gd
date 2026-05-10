extends Area3D

@onready var prompt_label3d = $PromptLabel3D
# Called when the node enters the scene tree for the first time.

@export_enum("Pistol", "SMG", "Sniper", "Shotgun", "AR") var zone_type: String

func _ready() -> void:
	prompt_label3d.visible = true
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var cam = get_viewport().get_camera_3d()
	if cam:
		prompt_label3d.look_at(cam.global_transform.origin, Vector3.UP)
	pass


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.nearby_items.append(self)
		print("Player entered")
	pass # Replace with function body.

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.nearby_items.erase(self)
		print("Player exited")
	pass # Replace with function body.

func apply_effect(body):
	# performs ammo reload logic
	body.refill_ammo(zone_type)

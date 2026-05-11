extends Area3D

@onready var prompt_label3d = $PromptLabel3D

@export_enum("Pistol", "SMG", "Sniper", "Shotgun", "AR") var zone_type: String = "Pistol"

var can_refill := true
var cooldown_time := 0.5

func _ready() -> void:
	print("AmmoZone ready, zone_type: ", zone_type)
	print("prompt_label3d: ", prompt_label3d)
	if prompt_label3d:
		prompt_label3d.visible = false
		prompt_label3d.text = "Press E - %s Ammo" % zone_type
	else:
		print("ERROR: PromptLabel3D node not found")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if not prompt_label3d:
		return

func _on_body_entered(body: Node3D) -> void:
	print("body entered zone: ", body.name, " groups: ", body.get_groups())
	if body.is_in_group("player"):
		print("Player detected — adding to nearby_items")
		body.nearby_ammo_zones.append(self)
		prompt_label3d.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.nearby_ammo_zones.erase(self)
		print("Player left zone")
		prompt_label3d.visible = false

func apply_effect(body) -> void:
	if not can_refill:
		return

	can_refill = false

	print("apply_effect called, zone_type: '%s'" % zone_type)
	body.refill_ammo(zone_type)

	await get_tree().create_timer(cooldown_time).timeout
	can_refill = true

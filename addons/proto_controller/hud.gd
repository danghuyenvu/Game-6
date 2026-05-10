extends Control

@onready var ammo_label = $AmmoLabel
@onready var health_bar = $HealthBar
@onready var health_text = $HealthText

var health = 100

func update_ammo(current, reserve):
	if ammo_label == null:
		print("HUD not ready yet")
		return

	ammo_label.text = str(current) + " / " + str(reserve)

func update_health(value):
	health = clamp(value, 0, 100)

	health_bar.value = health
	health_text.text = str(health)

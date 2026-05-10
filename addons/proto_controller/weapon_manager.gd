extends Node3D
class_name WeaponManager

@onready var primary_slot: Node3D = $PrimarySlot
@onready var secondary_slot: Node3D = $SecondarySlot
@onready var crosshair = get_node("/root/Node3D/ProtoController/CanvasLayer/Crosshair")

# ----------------------------
# DEV OVERRIDE (testing only)
# ----------------------------
@export var dev_primary: WeaponBase = null
@export var dev_secondary: WeaponBase = null

var primary_weapon: WeaponBase = null
var secondary_weapon: WeaponBase = null
var current_weapon: WeaponBase = null


func _ready():
	_init_weapons()


func _init_weapons():

	# ----------------------------
	# FORCE SECONDARY (ONLY ONE STARTING WEAPON)
	# ----------------------------
	if secondary_slot.get_child_count() > 0:
		secondary_weapon = secondary_slot.get_child(0) as WeaponBase
		secondary_weapon.unequip()

	# If nothing exists, player effectively starts unarmed (you can avoid this by always placing Base pistol)
	if secondary_weapon == null:
		push_warning("No secondary weapon found! Player starts unarmed.")

	# ----------------------------
	# PRIMARY ALWAYS STARTS EMPTY
	# ----------------------------
	primary_weapon = null

	# ----------------------------
	# DEV OVERRIDES (optional testing)
	# ----------------------------
	if dev_secondary:
		_set_secondary(dev_secondary)

	if dev_primary:
		_set_primary(dev_primary)

	# ----------------------------
	# START WITH SECONDARY ONLY
	# ----------------------------
	if secondary_weapon:
		switch_weapon(secondary_weapon)


# =====================================================
# INPUT
# =====================================================
func _input(event):
	if event is InputEventKey and event.pressed:

		if event.keycode == KEY_1:
			equip_primary()

		if event.keycode == KEY_2:
			equip_secondary()


# =====================================================
# EQUIP LOGIC
# =====================================================
func equip_primary():
	if primary_weapon == null:
		return

	switch_weapon(primary_weapon)


func equip_secondary():
	if secondary_weapon == null:
		return

	switch_weapon(secondary_weapon)


# =====================================================
# PICKUP SYSTEM
# =====================================================
func pickup_weapon(weapon: WeaponBase):

	if weapon == null:
		return

	if weapon.weapon_id == "pistol" or weapon.weapon_id == "base":
		_set_secondary(weapon)
	else:
		_set_primary(weapon)


func _set_primary(weapon: WeaponBase):

	if primary_weapon:
		primary_weapon.queue_free()

	primary_weapon = weapon
	primary_slot.add_child(primary_weapon)
	primary_weapon.unequip()


func _set_secondary(weapon: WeaponBase):

	if secondary_weapon:
		secondary_weapon.queue_free()

	secondary_weapon = weapon
	secondary_slot.add_child(secondary_weapon)
	secondary_weapon.unequip()


# =====================================================
# SWITCH CORE
# =====================================================
func switch_weapon(new_weapon: WeaponBase):

	if new_weapon == null:
		return

	if new_weapon == current_weapon:
		return

	if current_weapon:
		current_weapon.unequip()

	current_weapon = new_weapon
	current_weapon.equip()

	if current_weapon.has_method("update_hud"):
		current_weapon.update_hud()

	if crosshair:
		crosshair.set_weapon(current_weapon)


func get_current_weapon() -> WeaponBase:
	return current_weapon

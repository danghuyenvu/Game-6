extends Area3D

@onready var prompt_label3d: Label3D = $PromptLabel3D

var player_inside: Node3D = null

var current_weapon: String = ""
var rolled := false
var weapon_taken := false

var rng := RandomNumberGenerator.new()

var weapons := [
	"marksman",
	"awp",
	"revolver",
	"pistol",
	"magnum",
	"doublebarrel",
	"aug",
	"ak",
	"m14"
]

# -------------------------
# READY
# -------------------------
func _ready() -> void:
	rng.randomize()
	prompt_label3d.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	update_prompt()

# -------------------------
# ROLL (ONLY MANUAL)
# -------------------------
func roll_weapon() -> void:
	current_weapon = weapons[rng.randi_range(0, weapons.size() - 1)]
	rolled = true
	weapon_taken = false

	print("Weapon rolled:", current_weapon)
	update_prompt()

# -------------------------
# INTERACT (E)
# -------------------------
func interact(player: Node3D) -> void:

	# first time = roll
	if not rolled:
		roll_weapon()
		return

	# reroll if already rolled
	if not weapon_taken:
		roll_weapon()

# -------------------------
# TAKE (Q)
# -------------------------
func try_take_weapon(player: Node3D) -> void:
	if not rolled:
		return

	if weapon_taken:
		return

	if current_weapon == "":
		return

	weapon_taken = true

	print("Player took:", current_weapon)

	player.weapon_manager.pickup_weapon(current_weapon)

	update_prompt()

# -------------------------
# PROMPT
# -------------------------
func update_prompt() -> void:

	if player_inside == null:
		return

	if not rolled:
		prompt_label3d.text = "E: Roll Weapon"
	elif weapon_taken:
		prompt_label3d.text = "Taken - Press E to reroll"
	else:
		prompt_label3d.text = "Q: Take %s | E: Reroll" % current_weapon

# -------------------------
# AREA
# -------------------------
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = body
		body.nearby_weapon_box = self
		prompt_label3d.visible = true
		update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.nearby_weapon_box == self:
			body.nearby_weapon_box = null

		if body == player_inside:
			player_inside = null
			prompt_label3d.visible = false

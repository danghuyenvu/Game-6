extends Node3D

var items = [
	{"scene": preload("res://3d models/Items/Food/bottle.tscn"), "chance": 1/9},
	{"scene": preload("res://3d models/Items/Food/burger.tscn"), "chance": 1/9},
	{"scene": preload("res://3d models/Items/Food/hotdog.tscn"), "chance": 1/9},
	{"scene": preload("res://3d models/Items/Food/icecream.tscn"), "chance": 1/9},
	{"scene": preload("res://3d models/Items/Food/ketchup.tscn"), "chance": 1/9},
	{"scene": preload("res://3d models/Items/Food/mayo.tscn"), "chance": 1/9},
	{"scene": preload("res://3d models/Items/Food/samdwichfull.tscn"), "chance": 1/9},
	{"scene": preload("res://3d models/Items/Food/sausage.tscn"), "chance": 1/9},
	{"scene": preload("res://3d models/Items/Food/sause.tscn"), "chance": 1/9}
]

var spawned_item = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Start the timer for spawning items
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(spawn_items)
	
func spawn_items() -> void:
	# not spawning new item if the spawned item is not taken
	if spawned_item != null:
		return
	
	var roll = items.pick_random()
	# spawn item
	spawned_item = roll["scene"].instantiate()
	# Add to scene before touching global_transform
	get_tree().current_scene.add_child(spawned_item)
	var offset = Vector3(
		0.0,
		0.3,
		0.0
	)
	var base_coord = global_transform.origin
	spawned_item.global_transform.origin = base_coord + offset
	
	print("Spawning:", spawned_item, "at", global_transform.origin)
	
	spawned_item.tree_exited.connect(func(): spawned_item = null)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

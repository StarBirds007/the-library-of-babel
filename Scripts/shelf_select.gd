extends Control

@onready var wall = $Wall
@onready var option_button: OptionButton = $OptionButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(wall.get_child_count()):
		wall.get_child(i).pressed.connect(
		func set_wall():
			selected_address["wall"] = i
			option_button.selected = i)

	regex.compile("[^0-9a-z]")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

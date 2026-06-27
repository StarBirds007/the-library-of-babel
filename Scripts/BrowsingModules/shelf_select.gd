extends BrowsingModule

@onready var wall = $Wall
@onready var option_button: OptionButton = $OptionButton

var current_shelf: int = -1

signal changed_shelf(shelf: int)

var wall_buttons: Array[TextureButton]

func _ready() -> void:
	for i in range(wall.get_child_count()):
		wall_buttons.append(wall.get_child(i))
		wall_buttons[i].pressed.connect(func set_wall():
			_set_shelf(i))

	option_button.item_selected.connect(_set_shelf)


## Called by BrowsingWindow right before this step becomes visible.
func prepare(address: Dictionary) -> void:
	if address.has("shelf"):
		current_shelf = address["shelf"]
		option_button.selected = current_shelf

	step_ready.emit(current_shelf >= 0)


func _set_shelf(shelf: int) -> void:
	current_shelf = shelf
	option_button.selected = shelf
	changed_shelf.emit(shelf)
	field_selected.emit("shelf", shelf)
	step_ready.emit(true)

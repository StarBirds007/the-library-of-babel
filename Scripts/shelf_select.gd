extends Control

@onready var wall = $Wall
@onready var option_button: OptionButton = $OptionButton

signal changed_shelf(shelf: int)


func _ready() -> void:
	for i in range(wall.get_child_count()):
		wall.get_child(i).pressed.connect(func set_wall():
			changed_shelf.emit(i)
			option_button.selected = i)

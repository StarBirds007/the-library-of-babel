extends Control

@onready var shelf = $Shelf
@onready var label: Label = $Label


func _ready() -> void:
	for i in range(shelf.get_child_count()):
		shelf.get_child(i).mouse_entered.connect(func set_wall():
			label.text = "Selected Book: " + str(i + 1))
		shelf.get_child(i).mouse_exited.connect(func set_wall():
			label.text = "Selected Book: ")

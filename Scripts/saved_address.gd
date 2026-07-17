extends MarginContainer

@onready var index_label: Label = $HBoxContainer/IndexLabel
@onready var title_label: Label = $HBoxContainer/TitleLabel
@onready var delete_button: TextureButton = $HBoxContainer/DeleteButton
@onready var open_button: TextureButton = $HBoxContainer/OpenButton

signal delete_address(index: int)
signal visit_address(index: int)

var index: int
var title: String

func _ready() -> void:
	index_label.text = str(index)
	title_label.text = title
	delete_button.connect("pressed", _on_delete_button_pressed)
	open_button.connect("pressed", _on_open_button_pressed)


func _on_delete_button_pressed() -> void:
	delete_address.emit(index)


func _on_open_button_pressed() -> void:
	visit_address.emit(index)


func setter(index_value: int, title_value: String) -> void:
	index = index_value
	title = title_value
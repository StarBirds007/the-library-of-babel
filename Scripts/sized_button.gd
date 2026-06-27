@tool
extends Button
class_name SizedButton


func _ready() -> void:
	self.resized.connect(_on_resized)


func _on_resized() -> void:
	pivot_offset = size / 2.0
	position.x = (get_parent().size.x / 2.0) - size.x / 2.0
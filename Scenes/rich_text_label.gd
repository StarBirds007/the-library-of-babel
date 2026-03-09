@tool
extends RichTextLabel


func _on_resized() -> void:
	pivot_offset = size / 2

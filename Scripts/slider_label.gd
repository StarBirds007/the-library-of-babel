extends Label


func _on_page_value_changed(value:float) -> void:
	text = get_parent().name + ": " + str(value)

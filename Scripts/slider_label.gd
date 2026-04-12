extends Label


func _ready() -> void:
	_on_page_value_changed(get_parent().value)


func _on_page_value_changed(value:float) -> void:
	text = get_parent().name + ": " + str(value)

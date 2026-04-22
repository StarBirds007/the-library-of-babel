@tool
extends RichTextLabel


func _ready() -> void:
	adjust_size_from_font()


func adjust_size_from_font() -> void:
	var words = GlobalValues.WORDS
	var lines = GlobalValues.LINES
	var font: Font = get_theme_font("normal_font")
	var font_size: int = get_theme_font_size("normal_font_size")

	var char_width = font.get_char_size("A".unicode_at(0), font_size).x
	var char_height = font.get_char_size("A".unicode_at(0), font_size).y

	var required_width = char_width * words
	var required_height = char_height * lines

	size = Vector2(required_width, required_height)


func _on_resized() -> void:
	adjust_size_from_font()
	pivot_offset = size / 2
	position.x = (get_parent().size.x / 2) - size.x / 2

	$TitleTextLabel.pivot_offset = $TitleTextLabel.size / 2
	$TitleTextLabel.position.x = size.x / 2 - $TitleTextLabel.size.x / 2


func _on_item_rect_changed() -> void:
	adjust_size_from_font()
	position.x = (get_parent().size.x / 2) - size.x / 2


func _on_title_text_label_resized() -> void:
	_on_resized()


func _on_title_text_label_item_rect_changed() -> void:
	_on_item_rect_changed()

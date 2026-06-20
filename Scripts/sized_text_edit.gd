@tool
extends TextEdit
class_name SizedTextEdit

## Width of the box, measured in digit characters ("0").
@export var max_width: int = 20:
	set(value):
		max_width = max(0, value)
		_update_size()

## Height of the box, measured in digit characters ("0").
@export var max_height: int = 5:
	set(value):
		max_height = max(0, value)
		_update_size()

# Cached metrics so we only recompute size when something actually changed.
var _last_font: Font = null
var _last_font_size: int = -1
var _last_line_height: float = -1.0


func _ready() -> void:
	# Does not need to run at runtime, only in the editor.
	if !Engine.is_editor_hint():
		set_process(false)

	_update_size()
	resized.connect(_on_resized)
	theme_changed.connect(_update_size)


# Runs every frame in the editor (not at runtime) so the box stays correctly
# sized in real time even if the font, font size, or line spacing changes
# from somewhere other than this script (e.g. a theme override edited live
# in the inspector, or changed by another script while the game is running).
func _process(_delta: float) -> void:
	var font: Font = get_theme_font("font")
	var font_size: int = get_theme_font_size("font_size")
	var line_height: float = font.get_height(font_size) if font else -1.0

	if font != _last_font or font_size != _last_font_size or line_height != _last_line_height:
		_last_font = font
		_last_font_size = font_size
		_last_line_height = line_height
		_update_size()


func _update_size() -> void:
	var font: Font = get_theme_font("font")
	var font_size: int = get_theme_font_size("font_size")

	if font == null:
		return

	var digit_size: Vector2 = font.get_char_size("0".unicode_at(0), font_size)
	var char_width: float = digit_size.x
	var line_height: float = font.get_height(font_size)

	var required_width: float = char_width * max_width
	var required_height: float = line_height * max_height

	# Account for the TextEdit's own internal margins/gutters so the visible
	# text area actually matches max_width x max_height, not the outer box.
	var style: StyleBox = get_theme_stylebox("normal")
	if style:
		required_width += style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
		required_height += style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)

	if size != Vector2(required_width, required_height):
		size = Vector2(required_width, required_height)

	_center_pivot()


func _on_resized() -> void:
	_center_pivot()


func _center_pivot() -> void:
	pivot_offset = size / 2.0
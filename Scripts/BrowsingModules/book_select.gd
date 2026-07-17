extends BrowsingModule

@onready var shelf = $Shelf
@onready var label: Label = $Label

@export var selected_font: Font = null


var current_book: int:
	set(value):
		current_book = value
		field_selected.emit("book", value)
var titles: PackedStringArray = []
var spine_labels: Array[Label] = []
var required_font_size: int = 0

var retrieval_thread: Thread = null
var is_loading: bool = false

func _ready() -> void:
	for i in range(shelf.get_child_count()):
		var button: TextureButton = shelf.get_child(i)

		_add_title_labels(button)

		button.pressed.connect(_on_book_pressed.bind(i))
		button.disabled = true   # disabled until titles finish loading


func prepare(address: Dictionary) -> void:
	current_book = address["book"]

	step_ready.emit(false)
	_set_loading(true)

	if retrieval_thread and retrieval_thread.is_started():
		retrieval_thread.wait_to_finish()

	retrieval_thread = Thread.new()
	retrieval_thread.start(_fetch_titles.bind(address.duplicate()))


func _add_title_labels(button: TextureButton) -> void:
	var spine_label := Label.new()
	spine_label.rotation_degrees = 90.0
	spine_label.size.x = button.size.y
	spine_label.size.y = button.size.x
	spine_label.position.x += spine_label.size.y
	spine_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# spine_label.add_theme_color_override("font_color", Color.BLACK)
	# spine_label.set_anchors_preset(Control.PRESET_FULL_RECT, true)

	if required_font_size == 0:
		var char_width
		var total_width

		while (true):
			char_width = selected_font.get_char_size("A".unicode_at(0), required_font_size).x
			total_width = char_width * GlobalValues.TITLE
			if spine_label.size.x > total_width:
				required_font_size += 1
			else:
				required_font_size -= 1
				break
			print("Current Font Room: ", total_width, " / ", spine_label.size.x)
			print("FontSizeSelected: ", required_font_size)

	print(spine_label.size, spine_label.position)

	spine_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# spine_label.add_theme_font_override("font", selected_font)
	spine_label.add_theme_font_size_override("font_size", required_font_size)

	button.add_child(spine_label)
	spine_labels.append(spine_label)


func _fetch_titles(address: Dictionary) -> void:
	var result: PackedStringArray = BabelMath.MassTitleRetrieval(address)
	call_deferred("_on_titles_ready", result)


func _on_titles_ready(result: PackedStringArray) -> void:
	if retrieval_thread.is_alive():
			retrieval_thread.wait_to_finish()
	titles = result

	for i in range(shelf.get_child_count()):
		if i < titles.size():
			spine_labels[i].text = titles[i]
			shelf.get_child(i).disabled = false

	_set_loading(false)
	_on_book_pressed(current_book)


func _set_loading(loading: bool) -> void:
	is_loading = loading
	label.text = "Loading titles..." if loading else "Selected Book: "
	for button in shelf.get_children():
		button.disabled = loading


func _on_book_pressed(i: int) -> void:
	current_book = i
	field_selected.emit("book", i)
	step_ready.emit(true)
	label.text = "Selected Book: " + str(i + 1) + "\nTitle: " + titles[i]


func _exit_tree():
	pass
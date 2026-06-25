
extends Control

@onready var page: RichTextLabel = $BookFrame/Page
@onready var book_frame: TextureRect = $BookFrame
@onready var page_number: LineEdit = $PageNumberLabel/PageNumber
@onready var page_number_label: Label = $PageNumberLabel
@onready var title_label: Label = $BookFrame/TitleLabel
@onready var left: Button = $BookFrame/Left
@onready var right: Button = $BookFrame/Right
@onready var copyable_address: Button = $ShowAddress/CopyableAddress

@export var jitter_range: float = 5.0

var current_texture_index: int = 0
var current_page: int:
	set(value):
		current_page = value
		field_selected.emit("page", value)
		stored_address["page"] = value
var regex: RegEx = RegEx.new()
var stored_address: Dictionary

const random_frame_textures: Array = [
	preload("res://Assets/Sprite/BookFrameRandom/BookFrameRandom.png"),
	preload("res://Assets/Sprite/BookFrameRandom/BookFrameRandom2.png"),
	preload("res://Assets/Sprite/BookFrameRandom/BookFrameRandom3.png"),
	preload("res://Assets/Sprite/BookFrameRandom/BookFrameRandom4.png"),
	preload("res://Assets/Sprite/BookFrameRandom/BookFrameRandom5.png")
]

var retrieval_thread: Thread = null
var is_loading: bool = false

signal field_selected(field_name: String, value: Variant) # Automatically emitted when current_page is set.
signal step_ready(is_ready: bool)


func _ready() -> void:
	regex.compile("[^0-9]")
	copyable_address.pressed.connect(_on_copyable_address_pressed)


func prepare(address: Dictionary):
	_create_copyable_address(address)
	page_number.text = str(address["page"] + 1)
	current_page = address["page"]
	stored_address = address
	generate_page()


func generate_page(imported_page: int = -1) -> void:
	if (imported_page != -1):
		if imported_page == current_page:
			return
		else:
			current_page = imported_page

	print(current_page)

	_set_loading(true)

	if retrieval_thread and retrieval_thread.is_started():
		retrieval_thread.wait_to_finish()

	retrieval_thread = Thread.new()
	GlobalValues.debug_time = Time.get_ticks_msec()
	var result: Dictionary = BabelMath.GetPageAndTitleString(stored_address)
	call_deferred("_on_page_retrieved", result)


func _on_page_retrieved(result: Dictionary) -> void:
	if retrieval_thread.is_alive():
		retrieval_thread.wait_to_finish()
	page.text = result["page"]
	title_label.text = "Title: " + result["title"]

	_random_frame_sprite()
	step_ready.emit(true)
	_set_loading(false)
	

func _set_loading(loading: bool) -> void:
	is_loading = loading
	page_number_label.text = "Loading Book..." if loading else "Page     / 140"
	left.disabled = loading
	right.disabled = loading
	page_number.visible = not is_loading


func _random_frame_sprite() -> void:
	var random_texture_index: int = 0

	while true:
		random_texture_index = randi() % random_frame_textures.size()
		if random_texture_index != current_texture_index:
			break

	book_frame.texture = random_frame_textures[random_texture_index]
	current_texture_index = random_texture_index

	book_frame.flip_h = current_page % 2 == 0


	_random_frame_jitter()


func _random_frame_jitter() -> void:
	var random_offset: Vector2 = Vector2(randf_range(-jitter_range, jitter_range), randf_range(-jitter_range, jitter_range))
	if book_frame.material is ShaderMaterial:
			book_frame.material.set_shader_parameter("offset_x", random_offset.x)
			book_frame.material.set_shader_parameter("offset_y", random_offset.y)


func _create_copyable_address(address: Dictionary):
	var hex_length: int = len(address["hex"])
	var hex_text: String

	if address["hex"] == "":
		hex_text = "0"
	elif hex_length <= 10:
		hex_text = address["hex"]
	elif hex_length <= 22:
		hex_text = "%s\n%s" % [address["hex"].substr(0, 10), address["hex"].substr(9)]
		print(address["hex"].substr(0, 10))
		print(address["hex"].substr(9))
	else:
		hex_text = "%s\n%s..." % [address["hex"].substr(0, 10), address["hex"].substr(9, 12)]

	copyable_address.text = "Hex: %s\nWall: %s\nShelf: %s\nBook: %s" % [hex_text, address["wall"] + 1, address["shelf"] + 1, address["book"] + 1]


func _on_left_pressed() -> void:
	current_page -= 1
	var clamped_value = max(0, current_page)

	if clamped_value != current_page:
		current_page = clamped_value
		return

	page_number.text = str(current_page + 1)
	generate_page()


func _on_right_pressed() -> void:
	current_page += 1
	var clamped_value = min(GlobalValues.PAGES - 1, current_page)

	if clamped_value != current_page:
		current_page = clamped_value
		return

	page_number.text = str(current_page + 1)
	generate_page()


func _on_page_number_text_changed(new_text:String) -> void:
	var input: String = new_text
	var caret_pos: int = page_number.get_caret_column()

	var filtered: String = regex.sub(input, "", true)
	var filtered_value = filtered.to_int() - 1

	if filtered != input:
		page_number.text = filtered

	elif (filtered_value < 0 or filtered_value > GlobalValues.PAGES) and not filtered == "":
		page_number.text = str(current_page + 1) 
		page_number.set_caret_column(caret_pos - 1)
	
	field_selected.emit("page", page_number.text.to_int() - 1)


func _on_page_number_gui_input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		print("Enter Pressed Within Label!")
		page_number.release_focus()
		generate_page(page_number.text.to_int() - 1)


func _on_check_box_toggled(toggled_on:bool) -> void:
	copyable_address.visible = toggled_on


func _on_copyable_address_pressed() -> void:
	var text_to_copy = "%s:%s:%s:%s:%s" % [stored_address["hex"], stored_address["wall"] + 1,\
	                                       stored_address["shelf"] + 1, stored_address["book"] + 1,\
										   stored_address["page"] + 1]
	DisplayServer.clipboard_set(text_to_copy)
	copyable_address.text = copyable_address.text + "\nAddress Copied!"
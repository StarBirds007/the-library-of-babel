extends Control

@onready var hexagon: TextureRect = $Hexagon
@onready var hex_text: TextEdit = $HexTextEdit
@onready var option_button: OptionButton = $OptionButton

@export var jitter_range: float = 5.0

var current_texture_index: int = 0
var last_text: String = ""
var regex: RegEx = RegEx.new()

signal changed_hex(hex: String)
signal changed_wall(wall: int)

const random_hex_textures: Array = [
	preload("res://Assets/Sprite/WallSelectRandom/WallSelect.png"),
	preload("res://Assets/Sprite/WallSelectRandom/WallSelectRandom1.png"),
	preload("res://Assets/Sprite/WallSelectRandom/WallSelectRandom2.png"),
	preload("res://Assets/Sprite/WallSelectRandom/WallSelectRandom3.png"),
	preload("res://Assets/Sprite/WallSelectRandom/WallSelectRandom4.png"),
	preload("res://Assets/Sprite/WallSelectRandom/WallSelectRandom5.png")
]


func _ready() -> void:
	for i in range(4):
		hexagon.get_child(i).pressed.connect(
		func set_wall():
			changed_wall.emit(i)
			option_button.selected = i)

	regex.compile("[^0-9a-z]")



func random_hex_sprite() -> void:
	if hex_text.text == "0" or hex_text.text == "":
		hexagon.texture = random_hex_textures[0]
		return
	var random_texture_index: int = 0

	while true:
		random_texture_index = randi() % random_hex_textures.size()
		if random_texture_index != current_texture_index:
			break

	hexagon.texture = random_hex_textures[random_texture_index]
	current_texture_index = random_texture_index

	random_hex_jitter()



func random_hex_jitter() -> void:
	var random_offset: Vector2 = Vector2(randf_range(-jitter_range, jitter_range), randf_range(-jitter_range, jitter_range))
	if hexagon.material is ShaderMaterial:
			hexagon.material.set_shader_parameter("offset_x", random_offset.x)
			hexagon.material.set_shader_parameter("offset_y", random_offset.y)

	for i in range(hexagon.get_child_count()):
		var child: TextureButton = hexagon.get_child(i)
		if child.material is ShaderMaterial:
			child.material.set_shader_parameter("offset_x", random_offset.x)
			child.material.set_shader_parameter("offset_y", random_offset.y)
			

func _on_sized_text_edit_text_changed() -> void:
	var input: String = hex_text.text
	var caret_pos = hex_text.get_caret_column()

	var filtered: String = regex.sub(input, "", true)

	if filtered != input:
		hex_text.text = filtered
		hex_text.set_caret_column(caret_pos - 1)

	changed_hex.emit(hex_text)

	if hex_text.text != last_text or (hex_text.text == "0" and last_text == ""):
		last_text = hex_text.text
		random_hex_sprite()




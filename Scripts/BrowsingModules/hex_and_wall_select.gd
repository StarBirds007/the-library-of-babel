extends BrowsingModule

@onready var hexagon: TextureRect = $Hexagon
@onready var hex_text: LineEdit = $HexTextEdit
@onready var option_button: OptionButton = $OptionButton

@export var jitter_range: float = 5.0

# Once the real, collected hex reaches this many characters, we stop showing
# it at all — we clear the box and put a "Collected the pasted text (...)"
# message in placeholder_text instead. Below that, the real characters are
# shown normally (no masking) — the user can see and edit a few hundred or
# a thousand characters just fine; this only kicks in for genuinely huge
# pastes, where rendering the full text is what causes the slowdown.
@export var large_text_threshold: int = 1000

var current_texture_index: int = 0
var last_text: String = ""
var regex: RegEx = RegEx.new()

var current_hex: String = ""
var current_wall: int = -1

# True while we are programmatically writing/clearing hex_text ourselves, so
# the text_changed signal that fires from that isn't reprocessed as if the
# user had typed/pasted it.
var _updating_display: bool = false

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
		func set_wall() -> void:
			_set_wall(i))

	option_button.item_selected.connect(_set_wall)

	regex.compile("[^0-9a-z]")

	# No max_length restriction at all (0 = unlimited) — the user can type or
	# paste as much as they want; typing/pasting is never blocked or
	# truncated. We only ever change what's DISPLAYED (via .text /
	# placeholder_text further down), never what's allowed as input.
	hex_text.max_length = 0


func prepare(address: Dictionary) -> void:
	if address.get("hex", "") != "":
		_apply_hex(address["hex"])
		random_hex_sprite()

	if address.has("wall"):
		current_wall = address["wall"]
		option_button.selected = current_wall

	_emit_ready_state()


func _set_wall(wall: int) -> void:
	current_wall = wall
	option_button.selected = wall
	changed_wall.emit(wall)
	field_selected.emit("wall", wall)
	_emit_ready_state()


func _emit_ready_state() -> void:
	var is_ready: bool = current_hex != null and current_wall >= 0
	step_ready.emit(is_ready)


func random_hex_sprite() -> void:
	if current_hex == "0" or current_hex == "":
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


func _on_sized_text_edit_text_changed(_new_text: String = "") -> void:
	# Ignore changes we triggered ourselves (clearing the box, etc.).
	if _updating_display:
		return

	var input: String = hex_text.text

	# If we're currently showing the "Collected the pasted text…" message
	# (i.e. the box is empty and has a placeholder), ANY new input from here —
	# whether typed or pasted — means the user is starting over. The old
	# value is dropped from memory entirely, per design: we don't want a
	# stale collected hex lingering once the user has clearly moved on.
	if hex_text.placeholder_text != "":
		_forget_collected_value()

	# A normal keystroke (typing one character, or backspace) changes the
	# buffer length by exactly 1 in either direction. A paste of real size
	# jumps it by a lot more than that in one text_changed firing.
	var jumped_by_a_paste: bool = absi(input.length() - last_text.length()) >= 10

	if jumped_by_a_paste:
		_apply_hex(input)
		return

	var caret_pos: int = hex_text.caret_column
	var filtered: String = regex.sub(input, "", true)

	if filtered != input:
		_updating_display = true
		hex_text.text = filtered
		_updating_display = false
		hex_text.caret_column = caret_pos - 1

	current_hex = hex_text.text
	field_selected.emit("hex", current_hex)
	_emit_ready_state()

	if hex_text.text != last_text or (hex_text.text == "0" and last_text == ""):
		last_text = hex_text.text
		random_hex_sprite()


# Single entry point for "the hex value just changed via a large paste".
# Input is never blocked or truncated, so by the time text_changed fires,
# hex_text.text already holds the complete real value (whatever was there
# before, plus whatever was just pasted in, spliced together by the LineEdit
# itself) — no manual combining needed.
func _apply_hex(raw: String) -> void:
	var filtered: String = regex.sub(raw, "", true)

	current_hex = filtered

	_updating_display = true
	if filtered.length() >= large_text_threshold:
		# Clear the box and move the confirmation into placeholder_text —
		# placeholder only shows while .text is empty, so there's nothing
		# left for the user to select/copy that could be mistaken for the
		# real value.
		hex_text.text = ""
		hex_text.placeholder_text = "Collected the pasted text (%s characters)" % filtered.length()
	else:
		hex_text.text = filtered
		hex_text.placeholder_text = ""
	_updating_display = false

	last_text = hex_text.text

	field_selected.emit("hex", current_hex)
	_emit_ready_state()
	random_hex_sprite()


# Discards a previously-collected large value the moment the user starts
# providing a new one (typing or pasting) after seeing the collected message.
func _forget_collected_value() -> void:
	current_hex = ""
	last_text = ""
	_updating_display = true
	hex_text.placeholder_text = ""
	_updating_display = false
extends Control


@onready var module_container: Control = $ModuleContainer
@onready var back_button: Button = $BackButton
@onready var next_button: Button = $NextButton

var steps: Array[Dictionary] = []
var current_index: int = -1
var is_transitioning: bool = false

@export var transition_shrink_scale: Vector2 = Vector2(0.85, 0.85)
@export var transition_expand_scale: Vector2 = Vector2(1.15, 1.15)
@export var transition_duration: float = 0.2

var selected_address: Dictionary = {
	"hex": "",
	"wall": 0,
	"shelf": 0,
	"book": 0,
	"page": 0
}
const HIERARCHY = ["hex", "wall", "shelf", "book", "page"]


func _ready() -> void:
	get_tree().root.size_changed.connect(_on_window_size_changed)


	back_button.pressed.connect(go_back)
	next_button.pressed.connect(go_next)

	_register_step($ModuleContainer/HexAndWallSelect, ["hex", "wall"])
	_register_step($ModuleContainer/ShelfSelect, ["shelf"])
	_register_step($ModuleContainer/BookSelect, ["book"])
	_register_step($ModuleContainer/BookInterface, ["page"])

	for step in steps:
		var module: Control = step["node"]
		module.visible = false
		module.process_mode = Node.PROCESS_MODE_DISABLED
		module.pivot_offset = module.size / 2.0

	_enter_step(0, true)


func _register_step(module: Control, owned_fields: Array) -> void:
	steps.append({
		"node": module,
		"fields": owned_fields,
		"ready": false
	})

	module.field_selected.connect(_on_field_selected.bind(steps.size() - 1))
	module.step_ready.connect(_on_step_ready.bind(steps.size() - 1))


func _on_window_size_changed():
	for step in steps:
		var module: Control = step["node"]
		module.pivot_offset = module.size / 2.0


func _on_field_selected(field_name: String, value: Variant, _step_index: int) -> void:
	selected_address[field_name] = value

	var start_index = HIERARCHY.find(field_name) + (2 if field_name == "hex" else 1)

	if start_index >= HIERARCHY.size() - 1:
		return

	for i in range(start_index, HIERARCHY.size()):
		var reset_key = HIERARCHY[i]
		
		if reset_key == "hex":
			selected_address[reset_key] = ""
		else:
			selected_address[reset_key] = 0


func _on_step_ready(is_ready: bool, step_index: int) -> void:
	steps[step_index]["ready"] = is_ready
	if step_index == current_index:
		next_button.disabled = not is_ready


func go_next() -> void:
	if is_transitioning:
		return
	if not steps[current_index]["ready"]:
		return
	if current_index == steps.size() - 1:
		steps[current_index]["node"].generate_page(selected_address["page"])
		return

	_enter_step(current_index + 1, true)


func go_back() -> void:
	if is_transitioning:
		return
	if current_index <= 0:
		return

	_enter_step(current_index - 1, false)


func _enter_step(target_index: int, going_forward: bool) -> void:
	var old_module: Control = steps[current_index]["node"] if current_index >= 0 else null
	var new_step: Dictionary = steps[target_index]
	var new_module: Control = new_step["node"]

	is_transitioning = true
	next_button.disabled = true
	back_button.disabled = true

	new_module.prepare(selected_address.duplicate())

	if old_module:
		await _transition_out(old_module, going_forward)
		old_module.process_mode = Node.PROCESS_MODE_DISABLED

	current_index = target_index

	new_module.process_mode = Node.PROCESS_MODE_INHERIT
	await _transition_in(new_module, going_forward)

	is_transitioning = false
	back_button.disabled = (current_index == 0)
	next_button.disabled = not new_step["ready"] and not steps[current_index]["node"].name == "BookInterface"
	next_button.text = "Get Page" if steps[current_index]["node"].name == "BookInterface" else "Next (Enter)"


func _transition_out(module: Control, going_forward: bool) -> void:
	var shrink: bool = !going_forward
	var target_scale: Vector2 = transition_shrink_scale if shrink else transition_expand_scale

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(module, "modulate:a", 0.0, transition_duration)
	tween.tween_property(module, "scale", target_scale, transition_duration)
	await tween.finished

	module.visible = false
	module.scale = Vector2.ONE
	module.modulate.a = 1.0


func _transition_in(module: Control, going_forward: bool) -> void:
	var start_scale: Vector2 = transition_expand_scale if !going_forward else transition_shrink_scale

	module.visible = true
	module.modulate.a = 0.0
	module.scale = start_scale

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(module, "modulate:a", 1.0, transition_duration)
	tween.tween_property(module, "scale", Vector2.ONE, transition_duration)
	await tween.finished
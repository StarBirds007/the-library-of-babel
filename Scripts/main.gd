extends Control

var menus: Dictionary = {"Browse"  : preload("res://Scenes/UI/BrowsingWindow/browsing_window.tscn"),
						 "Search"  : preload("res://Scenes/UI/search.tscn"),
						 "Saved"   : preload("res://Scenes/UI/saved.tscn"),
						 "Options" : preload("res://Scenes/UI/options.tscn"),
						 "Exit"    : null}

@onready var main_title: Label = $Menu/MainTitle
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var buttons: Control = $Menu/Buttons
@onready var menu: Control = $Menu
@onready var hexagon_parallax: Parallax2D = $HexagonParallax
@onready var hexagon_particle: CPUParticles2D = $Menu/Particle/HexagonParticle

@export var transition_duration: float = 1.0

var character_pool: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz"
var active_animations: Array[Dictionary] = []
var transitioning: bool = false
var global_address: Dictionary = {
	"hex": "",
	"wall": 0,
	"shelf": 0,
	"book": 0,
	"page": 0
}

func _ready() -> void:
	for child in buttons.get_children():
		if child is Button:
			child.mouse_entered.connect(func scramble():
				AudioManager.create_audio(SoundEffect.SOUND_EFFECT_TYPE.HOVER)
				scramble_text(child, child.name, 50))

			child.pressed.connect(func button_pressed():
				if transitioning:
					return
				AudioManager.create_audio(SoundEffect.SOUND_EFFECT_TYPE.NEXT)
				if child.name == "Exit":
					get_tree().quit()
				else:
					_transition_out(menus[child.name].instantiate()))

			# child.disabled = true
	
	_transition_in(null, true)


func _process(delta: float) -> void:
	for i in range(active_animations.size() - 1, -1, -1):
		_process_text_animation(active_animations[i], delta, i)


func scramble_text(label_node: Node, target_text: String, iterations_per_second: float = 15.0) -> void:
	for anim in active_animations:
		if anim["label"] == label_node:
			return

	var current_chars: Array = []
	current_chars.resize(target_text.length())
	for i in range(target_text.length()):
		current_chars[i] = _get_random_char()
	
	var anim_state = {
		"label": label_node,
		"target": target_text,
		"current": current_chars,
		"speed": iterations_per_second,
		"timer": 0.0
	}
	
	active_animations.append(anim_state)
	
	label_node.text = "".join(current_chars)


func _process_text_animation(anim: Dictionary, delta: float, index: int) -> void:
	anim["timer"] += delta
	var time_per_iteration = 1.0 / anim["speed"]
	
	while anim["timer"] >= time_per_iteration:
		anim["timer"] -= time_per_iteration
		
		var matches_target = true
		var target_str: String = anim["target"]
		var current_arr: Array = anim["current"]
		
		for i in range(target_str.length()):
			if current_arr[i] == target_str[i]:
				continue
			
			while (true):
				var random_char = _get_random_char()
				if current_arr[i] != random_char:
					current_arr[i] = random_char
					break

			matches_target = false
			
		if is_instance_valid(anim["label"]):
			anim["label"].text = "".join(current_arr)
		
		if matches_target:
			active_animations.remove_at(index)
			break


func _get_random_char() -> String:
	return character_pool[randi() % character_pool.length()]


func _transition_out(module: Node, open_book: bool = false, exiting_module: Node = null) -> void:
	transitioning = true

	if exiting_module:
		exiting_module.queue_free()

	if open_book:
		module.selected_address = global_address
		module.initial_step = 3

	if "open_book" in module:
		module.open_book.connect(_show_searched_book)

	module.exiting.connect(_transition_in)

	add_child(module)

	hexagon_parallax.modulate.a = 0.0
	hexagon_parallax.visible = true
	hexagon_particle.emitting = false
	menu.visible = false

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)

	# tween.tween_property(menu, "modulate:a", 0.0, 0.1)
	tween.tween_property(hexagon_parallax, "modulate:a", 1.0, transition_duration)
	# tween.tween_property(module, "modulate:a", 1.0, transition_duration)
	await tween.finished

	transitioning = false


func _transition_in(module: Control = null, intro: bool = false) -> void:
	if transitioning:
		return

	if module:
		module.queue_free()
	
	menu.visible = true
	menu.modulate.a = 1
	hexagon_parallax.visible = false
	hexagon_particle.emitting = true
	# hexagon_particle.restart()

	if intro:
		animation_player.play("intro")
		scramble_text(main_title, main_title.text, 40)
	else:
		animation_player.play("RESET")

	await animation_player.animation_finished
	for child in buttons.get_children():
		child.disabled = false


func _show_searched_book(address: Dictionary, search_module: Node):
	global_address = address
	_transition_out(menus["Browse"].instantiate(), true,  search_module)
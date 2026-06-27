extends Control

@onready var main_title: Label = $Menu/MainTitle
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var buttons: Control = $Menu/Buttons

@export var character_pool: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz"

var active_animations: Array[Dictionary] = []


func _ready() -> void:
	scramble_text(main_title, main_title.text, 40)
	animation_player.play("intro")

	for child in buttons.get_children():
		if child is Button:
			child.mouse_entered.connect(func scramble():
				scramble_text(child, child.name, 50))



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
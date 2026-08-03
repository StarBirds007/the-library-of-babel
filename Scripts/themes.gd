extends Node

# Preload both themes
const THEMES = [preload("res://Assets/Themes/dark_theme.tres"),
				preload("res://Assets/Themes/light_theme.tres"),
				preload("res://Assets/Themes/gold_theme.tres")]
const BACKGROUND_COLOR = [Color("#0a0a0a"),
						  Color.WHITE,
						  Color("#1d160e")]
const SECONDARY_COLOR = [Color.WHITE,
						 Color.BLACK,
						 Color("#836625")]

enum ThemeMode { DARK, LIGHT, GOLD }
var current_mode = ThemeMode.LIGHT


func _ready() -> void:
	set_global_theme(current_mode)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("change_theme"):
		toggle_global_theme()
		GameOptions.save_game_options()


func set_global_theme(theme_index: int) -> void:
	if not ThemeMode.values().has(theme_index):
		return

	current_mode = theme_index

	RenderingServer.global_shader_parameter_set("global_secondary_color", SECONDARY_COLOR[current_mode])
	RenderingServer.global_shader_parameter_set("global_bg_color", BACKGROUND_COLOR[current_mode])
	get_tree().root.theme = THEMES[current_mode]

	# GameOptions.save_game_options()


func toggle_global_theme() -> void:
	var toggled_theme = (current_mode + 1) % ThemeMode.values().size()
	set_global_theme(toggled_theme)
extends Control

@onready var resolution_options: OptionButton = $ScrollContainer/VBoxContainer/Resolution/ResolutionOptions
@onready var theme_options: OptionButton = $ScrollContainer/VBoxContainer/Theme/ThemeOptions
@onready var full_screen_button: Button = $ScrollContainer/VBoxContainer/FullScreen/FullScreenButton

var available_themes = Themes.ThemeMode.keys()

var selected_theme: int = Themes.current_mode
var selected_resolution: Vector2 = GameOptions.video_options["resolution"]
var is_fullscreen_selected: bool = GameOptions.video_options["fullscreen"]

signal exiting
signal open_book

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	full_screen_button.text = "ON" if is_fullscreen_selected else "OFF"

	resolution_options.clear()

	for res in GameOptions.default_resolutions:
		var res_str: String = "%dx%d" % [res.x, res.y]
		resolution_options.add_item(res_str)
	
	theme_options.clear()

	for item in available_themes:
		theme_options.add_item(item)
	
	resolution_options.item_selected.connect(_on_resolution_selected)
	theme_options.item_selected.connect(_on_theme_selected)

	resolution_options.selected = GameOptions.default_resolutions.find(selected_resolution)
	theme_options.selected = selected_theme

func _on_resolution_selected(index: int) -> void:
	selected_resolution = GameOptions.default_resolutions[index]

func _on_theme_selected(index: int) -> void:
	selected_theme = index

func _on_apply_button_pressed() -> void:
	DisplayServer.window_set_size(selected_resolution)
	Themes.set_global_theme(selected_theme)
	GameOptions.set_game_resolution(selected_resolution)
	GameOptions.toggle_fullscreen(is_fullscreen_selected, false)
	GameOptions.save_game_options()

func _on_back_button_pressed() -> void:
	AudioManager.create_audio(SoundEffect.SOUND_EFFECT_TYPE.BACK)
	exiting.emit(self)

func _on_full_screen_button_pressed() -> void:
	is_fullscreen_selected = not is_fullscreen_selected
	full_screen_button.text = "ON" if is_fullscreen_selected else "OFF"
	GameOptions.video_options["fullscreen"] = is_fullscreen_selected
extends Node

var config: ConfigFile = ConfigFile.new()
var config_path: String = "user://game_options.ini"

var default_resolutions: Array[Vector2] = [
	Vector2(1920, 1080),
	Vector2(1600, 900),
	Vector2(1366, 768),
	Vector2(1280, 720),
	Vector2(1152, 648)
]

var video_options: Dictionary = {
    "fullscreen": false,
    "resolution": default_resolutions[4],
}


func _ready() -> void:
    _load_game_options()


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_fullscreen"):
        toggle_fullscreen()
        save_game_options()


func toggle_fullscreen(set_fullscreen: bool = false, toggle: bool = true) -> void:
    var current_mode = DisplayServer.window_get_mode()
    if set_fullscreen:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
        video_options["fullscreen"] = true
    elif toggle:
        if current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            video_options["fullscreen"] = false
        else:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
            video_options["fullscreen"] = true
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        video_options["fullscreen"] = false
    # save_game_options()


func set_game_resolution(resolution: Vector2) -> void:
    DisplayServer.window_set_size(resolution)
    video_options["resolution"] = resolution
    # save_game_options()


func save_game_options() -> void:
    config.set_value("VIDEO", "video_options", video_options)
    config.set_value("THEMES", "current_mode", Themes.current_mode)
    config.save(config_path)
    print("Saved game options: ", video_options)


func _load_game_options() -> void:
    var err = config.load(config_path)
    if err == OK:
        video_options = config.get_value("VIDEO", "video_options")
        Themes.set_global_theme(config.get_value("THEMES", "current_mode"))
        set_game_resolution(video_options["resolution"])
        toggle_fullscreen(video_options["fullscreen"], false)
    else:
        push_error("Failed to load game options: %s" % err)
    print("Loaded game options: ", video_options)
extends Node
class_name BrowsingModule

signal field_selected(field_name: String, value: Variant)
signal step_ready(is_ready: bool)

func play_hover_sound() -> void:
    AudioManager.create_audio(SoundEffect.SOUND_EFFECT_TYPE.HOVER)
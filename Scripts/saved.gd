extends Control

@onready var vbox_container: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var saved_address_scene: PackedScene = preload("res://Scenes/UI/saved_address.tscn")

signal exiting
signal open_book

var saved_addresses: Array = []

func _ready() -> void:
	saved_addresses = SaveManager.load_addresses()
	_populate_saved_addresses()


func _populate_saved_addresses() -> void:
	for child in vbox_container.get_children():
		child.queue_free()

	for i in range(saved_addresses.size()):
		var saved_address_instance: Control = saved_address_scene.instantiate()

		saved_address_instance.setter(i, saved_addresses[i]["title"])
		saved_address_instance.delete_address.connect(_on_delete_address)
		saved_address_instance.visit_address.connect(_on_visit_address)
		
		vbox_container.add_child(saved_address_instance)


func _on_delete_address(index: int) -> void:
	SaveManager.delete_address(index)
	saved_addresses = SaveManager.load_addresses()
	_populate_saved_addresses()


func _on_visit_address(index: int) -> void:
	open_book.emit(saved_addresses[index], self)


func _on_back_button_pressed() -> void:
	exiting.emit(self)
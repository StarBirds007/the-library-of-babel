extends Control

@onready var hex_and_wall_select: Control = $HexAndWallSelect
@onready var shelf_search: Control = $ShelfSearch

var tween: Tween = get_tree().create_tween().bind_node(self)

enum module {HEXANDWALL, SHELF, BOOK}
var current_module: int = module.HEXANDWALL:
	set(value):
		if (current_module + 1 == value):
			current_module = value
			transition(true)

		elif (current_module - 1 == value):
			current_module = value
			transition(false)

		else:
			print("Trying to skip steps!")
			return

var address_container: Dictionary = {
	"hex" : "",
	"wall" : 0,
	"shelf" : 0,
	"book" : 0,
	"page" : 0
}


signal bubble_up(address: Dictionary)


func _ready() -> void:
	hex_and_wall_select.changed_hex.connect(func set(value: String):
		address_container["hex"] = value
		bubble_up.emit(address_container))

	hex_and_wall_select.changed_wall.connect(func set(value: int):
		address_container["wall"] = value
		bubble_up.emit(address_container))

	shelf_search.changed_shelf.connect(func set(value: int):
		address_container["shelf"] = value
		bubble_up.emit(address_container))


func transition(forward: bool = true) -> void:
	if forward:
		pass
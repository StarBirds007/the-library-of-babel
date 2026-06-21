extends Control

@onready var hex_and_wall_select: Control = $HexAndWallSelect
@onready var shelf_search: Control = $ShelfSearch

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



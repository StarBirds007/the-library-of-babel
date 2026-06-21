extends Control

@onready var hex_and_wall_select: Control = $StepContainer/HexAndWallSelect
@onready var shelf_select: Control = $StepContainer/ShelfSelect


var selected_address: Dictionary = {
	"hex" : "",
	"wall" : 0,
	"shelf" : 0,
	"book" : 0,
	"page" : 0
}



extends Control

@onready var step_container: Control = $StepContainer


var selected_address: Dictionary = {
	"hex" : "",
	"wall" : 0,
	"shelf" : 0,
	"book" : 0,
	"page" : 0
}


func _ready() -> void:
	step_container.bubble_up.connect(func obtain_values(addreses: Dictionary):
		selected_address = addreses)

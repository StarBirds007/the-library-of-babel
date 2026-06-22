extends Control

@onready var module_container: Control = $ModuleContainer

var thread: Thread = Thread.new()

var selected_address: Dictionary = {
	"hex" : "",
	"wall" : 0,
	"shelf" : 0,
	"book" : 0,
	"page" : 0
}


func _ready() -> void:
	print(BabelMath.MassTitleRetrieval(selected_address))
	module_container.bubble_up.connect(func obtain_values(addreses: Dictionary) -> void:
		selected_address = addreses)

	GlobalValues.debug_time = Time.get_ticks_msec()
	thread.start(title_retrieval)


func title_retrieval() -> void:
	var result: Dictionary = BabelMath.MassTitleRetrieval(selected_address)
	print(result)

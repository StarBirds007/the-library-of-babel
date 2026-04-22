extends Control

var regex: RegEx = RegEx.new()
var thread: Thread = Thread.new()
var start_time: int = 0
var end_time: int = 0
var current_book: String = ""
var current_title: String = ""
var debug_time: float = 0.0

const WALLS = 4
const SHELVES = 5
const BOOKS = 32
const PAGES = 140
const LINES = 40
const WORDS = 80

# Variables currently selected, used for display
@onready var selected_address: Dictionary = {
	"hex" : $Hex.text,
	"wall" : $Wall.value - 1,
	"shelf" : $Shelf.value - 1,
	"book" : $Book.value - 1,
	"page" : $Page.value - 1
}

# Variables that are active right now
@onready var address: Dictionary = {
	"hex" : null,
	"wall" : null,
	"shelf" : null,
	"book" : null,
	"page" : null
}



func _ready() -> void:
	regex.compile("[^0-9a-z]")
	refresh_text_box()



func refresh_text_box(page_only: bool = false) -> void:
	if thread.is_started():
		return
	
	if address == selected_address:
		print("No changes detected, not refreshing.")
		print_page()
		return

	start_time = Time.get_ticks_msec()
	ui_toggle(false)
	$Status.text = "Searching the library..."

	print("Hex is " + str(selected_address["hex"].length()) + " characters long.\n")

	# Update the active variables to match the selected ones
	# Page only is for the next and previous buttons, because we don't want to update the hex or location when just changing the page
	# Also, we set the value of the selected address to match the active one.
	if not page_only:
		address["hex"] = selected_address["hex"]
		address["wall"] = selected_address["wall"]
		address["shelf"] = selected_address["shelf"]
		address["book"] = selected_address["book"]
		address["page"] = selected_address["page"]
	else:
		selected_address["hex"] = address["hex"]
		selected_address["wall"] = address["wall"]
		selected_address["shelf"] = address["shelf"]
		selected_address["book"] = address["book"]
		address["page"] = selected_address["page"]
		ui_update()

	GlobalValues.debug_time = Time.get_ticks_msec()
	thread.start(_thread_func)
	
	

func _thread_func():
	var result: Dictionary = BabelMath.GetPageAndTitleString(address)
	call_deferred("_thread_finished", result)



func _thread_finished(result: Dictionary) -> void:
	thread.wait_to_finish()

	current_book = "[center]" + result["book"] + "[/center]"
	current_title = "[center]" + result["title"] + "[/center]"

	print_page()

	end_time = Time.get_ticks_msec()
	$Status.text = "Search completed in " + str((end_time - start_time) / 1000.0)\
	 + " seconds."

	ui_toggle(true)



func print_page() -> void:
	$PageTextLabel.text = current_book
	$PageTextLabel.get_child(0).text = current_title






# Button and input handlers below. Not much to see here.

func _on_page_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= PAGES:
		selected_address["page"] = int_value - 1
	


func _on_book_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= BOOKS:
		selected_address["book"] = int_value - 1
		


func _on_shelf_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= SHELVES:
		selected_address["shelf"] = int_value - 1
		


func _on_wall_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= WALLS:
		selected_address["wall"] = int_value - 1
		


func _on_hex_text_changed() -> void:
	var input: String = $Hex.text
	var caret_pos = $Hex.get_caret_column()

	var filtered: String = regex.sub(input, "", true)

	if filtered != input:
		$Hex.text = filtered
		$Hex.set_caret_column(caret_pos - 1)
	
	selected_address["hex"] = $Hex.text if $Hex.text != "" else "0"
	


func _on_refresh_button_pressed() -> void:
	refresh_text_box()



func ui_toggle(enable_ui: bool) -> void:
	$Hex.editable = enable_ui
	$Wall.editable = enable_ui
	$Shelf.editable = enable_ui
	$Book.editable = enable_ui
	$Page.editable = enable_ui
	$RefreshButton.disabled = not enable_ui
	$Next.disabled = not enable_ui
	$Previous.disabled = not enable_ui



func ui_update() -> void:
	$Hex.text = address["hex"]
	$Wall.value = address["wall"] + 1
	$Shelf.value = address["shelf"] + 1
	$Book.value = address["book"] + 1
	$Page.value = address["page"] + 1



func _input(event):
	if event.is_action_pressed("ui_accept"):
		refresh_text_box()



func _on_next_pressed() -> void:
	selected_address["page"] += 1
	$Page.value = selected_address["page"] + 1
	refresh_text_box()



func _on_previous_pressed() -> void:
	selected_address["page"] -= 1
	$Page.value = selected_address["page"] + 1
	refresh_text_box()
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
@onready var s_hexagon: String = $Hex.text
@onready var s_wall: int = $Wall.value - 1
@onready var s_shelf: int = $Shelf.value - 1
@onready var s_book: int = $Book.value - 1
@onready var s_page: int = $Page.value - 1

# Variables that are active right now
var hexagon: String = s_hexagon
var wall: int = s_wall
var shelf: int = s_shelf
var book: int = s_book
var page: int = s_page



func _ready() -> void:
	regex.compile("[^0-9a-z]")
	refresh_text_box()



func refresh_text_box() -> void:
	if thread.is_started():
		return
	
	if s_hexagon == hexagon and s_wall == wall and s_shelf == shelf and s_book == book and s_page == page:
		print("No changes detected, not refreshing.")
		print_page()
		return

	start_time = Time.get_ticks_msec()
	$RefreshButton.disabled = true
	$Status.text = "Searching the library..."

	thread.start(_thread_func)
	
	

func _thread_func() -> Dictionary:
	print("Hex is " + str(s_hexagon.length()) + " characters long.\n")

	# Update the active variables to match the selected ones
	hexagon = s_hexagon
	wall = s_wall
	shelf = s_shelf
	book = s_book
	page = s_page

	GlobalValues.debug_time = Time.get_ticks_msec()

	return BabelMath.GetPageString(s_hexagon, s_wall, s_shelf, s_book, s_page)



func _process(_delta: float) -> void:
	if thread.is_started() and not thread.is_alive():
		var result = thread.wait_to_finish()

		current_book = "[center]" + result["book"] + "[/center]"
		current_title = "[center]" + result["title"] + "[/center]"

		print_page()

		end_time = Time.get_ticks_msec()
		$Status.text = "Search completed in " + str((end_time - start_time) / 1000.0)\
		 + " seconds."

		$RefreshButton.disabled = false



func print_page() -> void:
	$PageTextLabel.text = current_book
	$PageTextLabel.get_child(0).text = current_title






# Button and input handlers below. Not much to see here.

func _on_page_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= PAGES:
		s_page = int_value - 1
	


func _on_book_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= BOOKS:
		s_book = int_value - 1
		


func _on_shelf_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= SHELVES:
		s_shelf = int_value - 1
		


func _on_wall_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= WALLS:
		s_wall = int_value - 1
		


func _on_hex_text_changed() -> void:
	var input: String = $Hex.text
	var caret_pos = $Hex.get_caret_column()

	var filtered: String = regex.sub(input, "", true)

	if filtered != input:
		$Hex.text = filtered
		$Hex.set_caret_column(caret_pos - 1)
	
	s_hexagon = $Hex.text if $Hex.text != "" else "0"
	


func _on_refresh_button_pressed() -> void:
	refresh_text_box()


func _on_next_pressed() -> void:
	s_page += 1
	$Page.value = s_page + 1
	refresh_text_box()



func _on_previous_pressed() -> void:
	s_page -= 1
	$Page.value = s_page + 1
	refresh_text_box()
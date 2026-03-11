extends Control

var regex: RegEx = RegEx.new()
var thread: Thread = Thread.new()
var start_time: int = 0
var end_time: int = 0

const WALLS = 4
const SHELVES = 5
const BOOKS = 32
const PAGES = 140
const LINES = 40
const WORDS = 80

@onready var s_hexagon: String = $Hex.text
@onready var s_wall: int = $Wall.value
@onready var s_shelf: int = $Shelf.value
@onready var s_book: int = $Book.value
@onready var s_page: int = $Page.value



func _ready() -> void:
	regex.compile("[^0-9a-fA-F]")
	refresh_text_box()


func get_page(hexagon: String, wall: int, shelf: int, book: int, page: int):

	var page_value = BigCat.BigNumber.from_hex(hexagon)
	page_value = page_value.multiply_uint(WALLS).add_uint(wall)
	page_value = page_value.multiply_uint(SHELVES).add_uint(shelf)
	page_value = page_value.multiply_uint(BOOKS).add_uint(book)
	page_value = page_value.multiply_uint(PAGES).add_uint(page)
	print("Calculated page value: " + page_value.to_hex())
	return page_value


func dec_to_base29(page) -> String:
	var zero = BigCat.BigNumber.from_uint(0)
	var base = BigCat.BigNumber.from_uint(29)
	var characters = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", \
	"m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", " ", ",", "."]
	var output = []
	var remainder: int = 0

	while page.is_greater_than(zero):
		remainder = page.modulo(base).to_uint()
		output.append(characters[remainder])
		page = page.divide(base)

	output.reverse()
	output = "".join(output)

	if output.length() < LINES * WORDS:
		output = "a".repeat(LINES * WORDS - output.length()) + output

	return output



func refresh_text_box() -> void:
	if thread.is_started():
		return
	
	start_time = Time.get_ticks_msec()
	$RefreshButton.disabled = true
	$Status.text = "Searching the library..."

	thread.start(_thread_func)
	
	

func _thread_func() -> String:
	return dec_to_base29((get_page(s_hexagon, s_wall, s_shelf, s_book, s_page)))



func _process(_delta: float) -> void:
	if thread.is_started() and not thread.is_alive():
		var result = thread.wait_to_finish()
		$RichTextLabel.text = "[center]" + result + "[/center]"
		
		end_time = Time.get_ticks_msec()
		$Status.text = "Search completed in " + str((end_time - start_time) / 1000.0)\
		 + " seconds."
		
		$RefreshButton.disabled = false



func _on_page_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= PAGES:
		s_page = int_value
	


func _on_book_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= BOOKS:
		s_book = int_value
		


func _on_shelf_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= SHELVES:
		s_shelf = int_value
		


func _on_wall_value_changed(value:float) -> void:
	var int_value = max(0, int(value))
	if int_value <= WALLS:
		s_wall = int_value
		


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

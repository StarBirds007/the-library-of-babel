extends Control

const WALLS = 4
const SHELVES = 5
const BOOKS = 32
const PAGES = 140
const LINES = 40
const WORDS = 80

var s_hexagon: String = "0"
var s_wall: int = 0
var s_shelf: int = 0
var s_book: int = 0
var s_page: int = 0


func get_page(hexagon: String, wall: int, shelf: int, book: int, page: int):

	var page_value = BigCat.BigNumber.from_hex(hexagon)
	page_value = page_value.multiply_uint(WALLS).add_uint(wall)
	page_value = page_value.multiply_uint(SHELVES).add_uint(shelf)
	page_value = page_value.multiply_uint(BOOKS).add_uint(book)
	page_value = page_value.multiply_uint(PAGES).add_uint(page)
	print(page_value.to_string())

	return page_value


func dec_to_base29(page) -> String:
	var characters = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", \
	"m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", " ", ",", "."]
	var output: String = ""
	var remainder: int = 0

	while page.is_greater_than(BigCat.BigNumber.from_uint(0)):
		remainder = page.modulo(BigCat.BigNumber.from_uint(29)).to_uint()
		output = characters[remainder] + output
		print(remainder)
		page = page.divide_uint(29)

	if output.length() < LINES * WORDS:
		print("padding...")
		output = ",".repeat(LINES * WORDS - output.length()) + output

	return output



func refresh_text_box() -> void:
	print("refreshing...")
	$RichTextLabel.text = "[center]" + dec_to_base29(get_page(s_hexagon, s_wall, s_shelf, s_book, s_page)) + \
	"[/center]"
	print("refreshed")


func _ready() -> void:
	refresh_text_box()


func _on_text_edit_4_text_changed() -> void:
	var value = max(0, int($TextEdit4.text))
	if value <= PAGES:
		s_page = value
		refresh_text_box()


func _on_text_edit_3_text_changed() -> void:
	var value = max(0, int($TextEdit3.text))
	if value <= BOOKS:
		s_book = value
		refresh_text_box()


func _on_text_edit_2_text_changed() -> void:
	var value = max(0, int($TextEdit2.text))
	if value <= SHELVES:
		s_shelf = value
		refresh_text_box()


func _on_text_edit_text_changed() -> void:
	var value = max(0, int($TextEdit.text))
	if value <= WALLS:
		s_wall = value
		refresh_text_box()

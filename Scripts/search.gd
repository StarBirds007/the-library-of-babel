extends Control

@onready var search_text_edit: VirtualTextEdit = $SearchFrame/SearchTextEdit
@onready var search_page: Button = $SearchPage
@onready var back_button: Button = $BackButton
@onready var search_title_edit: LineEdit = $SearchTitleEdit

var regex: RegEx = RegEx.new()
var is_loading: bool = false
var search_thread := Thread.new()
const MAX_SEARCH_LENGTH: int = GlobalValues.PAGES * GlobalValues.LINES * GlobalValues.WORDS

signal exiting
signal open_book


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	search_title_edit.max_length = GlobalValues.TITLE
	search_title_edit.text_changed.connect(_on_search_title_changed)
	search_text_edit.text_changed.connect(_on_search_text_changed)
	regex.compile("[^a-zA-Z ,\\.]+")


func _set_loading(loading: bool) -> void:
	is_loading = loading
	search_page.text = "Searching..." if loading else "Search Page"
	search_page.disabled = loading
	back_button.disabled = loading


func _on_search_title_changed(input: String) -> void:
	var caret_pos: int = search_title_edit.get_caret_column()
	var filtered: String = regex.sub(input, "", true)
	filtered = filtered.to_lower()

	if filtered != input:
		search_title_edit.text = filtered
		var removed_chars: int = input.length() - filtered.length()
		search_title_edit.set_caret_column(max(0, caret_pos - removed_chars))


func _on_search_text_changed() -> void:
	print("search text changed")
	var input: String = search_text_edit.text

	if input.length() > MAX_SEARCH_LENGTH:
		input = input.left(MAX_SEARCH_LENGTH)
		search_text_edit.set_caret_column(MAX_SEARCH_LENGTH)

	print("input: %s" % input)
	var caret_pos: int = search_text_edit.get_caret_column() 

	var filtered: String = regex.sub(input, "", true)
	filtered = filtered.to_lower()
	print("filtered: %s" % filtered)
	if filtered != input:
		search_text_edit.text = filtered
		var removed_chars: int = input.length() - filtered.length()
		search_text_edit.set_caret_column(max(0, caret_pos - removed_chars))


func _on_search_book_pressed() -> void:
	if search_text_edit.text == "":
		search_text_edit.placeholder_text = "Enter Your Search Text Here!!!"
		return
	_set_loading(true)
	search_thread.start(_search_process.bind(false))


func _on_search_page_pressed() -> void:
	if search_text_edit.text == "":
		search_text_edit.placeholder_text = "Enter Your Search Text Here!!!"
		return
	_set_loading(true)
	search_thread.start(_search_process.bind(true))


func _search_process(page_only: bool):
	var search_title = search_title_edit.text
	if search_title == "":
		search_title = null
	var result: Dictionary

	if page_only:
		result = BabelMath.SearchFullPageRandomBook(search_text_edit.text, search_title)
	else:
		result = BabelMath.SearchBook(search_text_edit.text, search_title)

	call_deferred("_on_search_completed", result)


func _on_search_completed(result: Dictionary):
	if search_thread.is_alive():
		search_thread.wait_to_finish()
	open_book.emit(result, self)
	_set_loading.call_deferred(false)
	# print(result)


func _on_back_button_pressed() -> void:
	exiting.emit(self)
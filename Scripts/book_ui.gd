extends CanvasLayer

var is_book_view: bool = true


func _ready() -> void:
	$SearchView.search_completed.connect(_on_search_completed)


func _input(event):
	if event.is_action_pressed("switch_ui"):
		switch_mode()


func book_view():

	$BookView.show()
	$SearchView.hide()


func search_view():

	$BookView.hide()
	$SearchView.show()


func _on_search_completed(result: Dictionary) -> void:
	book_view()
	$BookView.selected_address = result
	$BookView.refresh_text_box()
	$BookView.ui_update()


func switch_mode():
	if is_book_view:
		if $BookView.thread.is_started():
			return
		search_view()
	else:
		if $SearchView.thread.is_started():
			return
		book_view()
	is_book_view = !is_book_view


func _on_button_pressed() -> void:
	switch_mode()
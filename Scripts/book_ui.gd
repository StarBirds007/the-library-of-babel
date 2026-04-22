extends CanvasLayer

var is_book_view: bool = true


func _ready() -> void:
	$SearchView.search_completed.connect(_on_search_completed)



func _input(event):
	if event.is_action_pressed("switch_ui"):
		if is_book_view:
			search_view()
		else:
			book_view()
		is_book_view = !is_book_view

func book_view():
	if $SearchView.thread.is_started():
		return
	$BookView.show()
	$SearchView.hide()


func search_view():
	if $BookView.thread.is_started():
		return
	$BookView.hide()
	$SearchView.show()



func _on_search_completed(result: Dictionary) -> void:
	book_view()
	$BookView.selected_address = result
	$BookView.refresh_text_box()
	$BookView.ui_update()
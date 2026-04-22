extends Control

var thread: Thread = Thread.new()
var text_to_search: String = ""
signal search_completed(result)



func _on_page_search_pressed() -> void:
	if thread.is_started():
		return
	
	ui_toggle(false)

	thread.start(_thread_func)



func _thread_func() -> void:
	var result = BabelMath.SearchEmptyPageRandomBook(text_to_search)
	call_deferred("_thread_finished", result)



func _thread_finished(result: Dictionary) -> void:
	thread.wait_to_finish()

	ui_toggle(true)

	search_completed.emit(result)




func ui_toggle(enable_ui: bool) -> void:
	$PageSearch.disabled = !enable_ui
	$TitleSearch.disabled = !enable_ui
	$TextEdit.editable = enable_ui



func _on_text_edit_text_changed() -> void:
	text_to_search = $TextEdit.text

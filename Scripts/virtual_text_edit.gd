@tool
class_name VirtualTextEdit
extends Control

## Ground-up text editor Control. Does not extend TextEdit - see chat for why.
## Virtualization: _lines holds ALL text cheaply; only on-screen rows are
## measured/drawn/hit-tested per frame, regardless of document size.

signal text_changed
signal caret_changed
signal lines_edited_from(from_line: int, to_line: int)

enum WrapMode { NONE, BOUNDARY, ARBITRARY }
enum CaretType { LINE, BLOCK }

@export_group("Text")
@export_multiline var text: String = "":
	get:
		return "\n".join(_lines)
	set(value):
		_lines = value.split("\n")
		if _lines.is_empty():
			_lines = [""]
		_caret_line = 0
		_caret_col = 0
		_clear_selection()
		_row_cache.clear()
		_wrap_cache.clear()
		_update_scrollbars()
		queue_redraw()
		text_changed.emit()

@export var placeholder_text: String = ""
@export var editable: bool = true
@export var context_menu_enabled: bool = true
@export var selecting_enabled: bool = true
@export var deselect_on_focus_loss_enabled: bool = true
@export var shortcut_keys_enabled: bool = true

@export_group("Appearance")
@export_subgroup("Caret")
@export var caret_type: CaretType = CaretType.LINE
@export var caret_blink: bool = true
@export var caret_blink_interval: float = 0.5
@export var caret_width: int = 1

@export_subgroup("Gutters")
@export var show_line_numbers: bool = false:
	set(v):
		show_line_numbers = v
		queue_redraw()
@export var line_numbers_zero_padded: bool = false

@export_subgroup("Highlighting")
@export var highlight_current_line: bool = false
@export var highlight_all_occurrences: bool = true

@export_subgroup("Lines")
@export var line_height: float = 20.0
@export var padding: Vector2 = Vector2(6, 4)

@export_group("Scroll")
@export var scroll_smooth: bool = true
@export var scroll_past_end_of_file: bool = false
@export var v_scroll_speed: float = 80.0

@export_group("Wrap")
@export var wrap_mode: WrapMode = WrapMode.NONE:
	set(v):
		wrap_mode = v
		_row_cache.clear()
		_wrap_cache.clear()
		_update_scrollbars()
		queue_redraw()
@export var tab_size: int = 4

# --- model -------------------------------------------------------------
var _lines: PackedStringArray = [""]
var _caret_line: int = 0
var _caret_col: int = 0
var _caret_visible: bool = true
var _caret_wants_x: float = -1.0

var _sel_active: bool = false
var _sel_anchor_line: int = 0
var _sel_anchor_col: int = 0

var _dragging: bool = false
var _last_click_time: int = 0
var _last_click_pos: Vector2 = Vector2.ZERO
var _click_count: int = 0

var _v_scroll: VScrollBar
var _h_scroll: HScrollBar
var _caret_timer: Timer
var _menu: PopupMenu

# lazily measured wrap-row counts, used only to estimate total scroll
# height; exact per-frame wrapping only ever runs on visible lines.
var _row_cache: Dictionary = {}
var _wrap_cache: Dictionary = {}
var _avg_rows: float = 1.0
var _max_line_width_seen: float = 0.0

var _undo_stack: Array = []
var _redo_stack: Array = []
var _last_undo_push_msec: int = 0
var _last_edit_was_insert: bool = true


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_IBEAM

	_v_scroll = VScrollBar.new()
	_v_scroll.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_v_scroll.anchor_left = 1.0
	_v_scroll.offset_left = -16
	add_child(_v_scroll)
	_v_scroll.value_changed.connect(func(_v): queue_redraw())

	_h_scroll = HScrollBar.new()
	_h_scroll.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_h_scroll.anchor_top = 1.0
	_h_scroll.offset_top = -16
	_h_scroll.offset_right = -16
	add_child(_h_scroll)
	_h_scroll.value_changed.connect(func(_v): queue_redraw())

	_caret_timer = Timer.new()
	_caret_timer.wait_time = caret_blink_interval
	_caret_timer.timeout.connect(_on_caret_blink)
	add_child(_caret_timer)
	if caret_blink:
		_caret_timer.start()

	_menu = PopupMenu.new()
	_menu.add_item("Cut", 0)
	_menu.add_item("Copy", 1)
	_menu.add_item("Paste", 2)
	_menu.add_separator()
	_menu.add_item("Select All", 3)
	_menu.add_separator()
	_menu.add_item("Undo", 4)
	_menu.add_item("Redo", 5)
	_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_menu)

	resized.connect(_update_scrollbars)
	_update_scrollbars()


func _get_minimum_size() -> Vector2:
	return Vector2(0, line_height + padding.y * 2)


# --- theming: reads the built-in TextEdit theme type, so this node
# tracks the project theme (and any TextEdit overrides) automatically.
func _tc(name: String) -> Color:
	return get_theme_color(name, "TextEdit")

func _tconst(name: String) -> int:
	return get_theme_constant(name, "TextEdit")

func _tfont() -> Font:
	return get_theme_font("font", "TextEdit")

func _tfont_size() -> int:
	return get_theme_font_size("font_size", "TextEdit")

func _tstyle(name: String) -> StyleBox:
	return get_theme_stylebox(name, "TextEdit")


# --- public API, mirrors TextEdit's where practical ---------------------
func get_line_count() -> int:
	return _lines.size()

func get_line(idx: int) -> String:
	return _lines[idx] if idx >= 0 and idx < _lines.size() else ""

func get_caret_line() -> int:
	return _caret_line

func get_caret_column() -> int:
	return _caret_col

func set_caret_line(l: int) -> void:
	_caret_line = clamp(l, 0, _lines.size() - 1)
	_caret_col = min(_caret_col, _lines[_caret_line].length())
	_after_caret_move()

func set_caret_column(c: int) -> void:
	_caret_col = clamp(c, 0, _lines[_caret_line].length())
	_after_caret_move()

func has_selection() -> bool:
	return _sel_active and (_sel_anchor_line != _caret_line or _sel_anchor_col != _caret_col)

func select(from_line: int, from_col: int, to_line: int, to_col: int) -> void:
	_sel_active = true
	_sel_anchor_line = from_line
	_sel_anchor_col = from_col
	_caret_line = to_line
	_caret_col = to_col
	queue_redraw()

func select_all() -> void:
	select(0, 0, _lines.size() - 1, _lines[_lines.size() - 1].length())

func deselect() -> void:
	_clear_selection()
	queue_redraw()

func get_selected_text() -> String:
	if not has_selection():
		return ""
	var a: Array = _normalized_selection()
	var sl: int = a[0]; var sc: int = a[1]; var el: int = a[2]; var ec: int = a[3]
	if sl == el:
		return _lines[sl].substr(sc, ec - sc)
	var out: PackedStringArray = [_lines[sl].substr(sc)]
	for i in range(sl + 1, el):
		out.append(_lines[i])
	out.append(_lines[el].substr(0, ec))
	return "\n".join(out)

func insert_text_at_caret(t: String) -> void:
	_push_undo(true)
	if has_selection():
		_delete_selection_no_undo()
	_splice_in(t)
	_row_cache.clear(); _wrap_cache.clear()
	_after_edit()

func clear() -> void:
	text = ""

func clear_undo_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()

func undo() -> void:
	_apply_history(_undo_stack, _redo_stack)

func redo() -> void:
	_apply_history(_redo_stack, _undo_stack)

## Override in a subclass to filter/sanitize text before it's inserted,
## e.g. `func _validate_text(t): return t.to_lower()`.
func _validate_text(t: String) -> String:
	return t


# --- scrollbars / virtualization sizing ---------------------------------
func _update_scrollbars() -> void:
	if _v_scroll == null:
		return
	var total_rows: float = _lines.size() * _avg_rows
	_v_scroll.max_value = max(0.0, total_rows * line_height + (size.y if scroll_past_end_of_file else 0.0))
	_v_scroll.page = size.y - 16
	_v_scroll.visible = _v_scroll.max_value > size.y

	var show_h: bool = wrap_mode == WrapMode.NONE
	_h_scroll.visible = show_h and _max_line_width_seen > _content_width()
	_h_scroll.max_value = _max_line_width_seen
	_h_scroll.page = _content_width()


func _content_width() -> float:
	return size.x - padding.x * 2 - _gutter_width() - (16 if _v_scroll.visible else 0)

func _gutter_width() -> float:
	if not show_line_numbers:
		return 0.0
	var digits: int = str(_lines.size()).length()
	return _tfont().get_string_size("0".repeat(digits), HORIZONTAL_ALIGNMENT_LEFT, -1, _tfont_size()).x + 12.0


## Breaks strictly on the character grid, ignoring word boundaries -
## needed for unbroken runs of characters wider than the box (long URLs,
## CJK text with no spaces, or garbage paste with no whitespace at all).
func _wrap_arbitrary(line: String, font: Font, fsize: int, avail: float) -> PackedStringArray:
	if line == "":
		return [""]
	var segs: PackedStringArray = []
	var start: int = 0
	while start < line.length():
		var lo: int = 1
		var hi: int = line.length() - start
		var fit: int = 1
		while lo <= hi:
			var mid: int = (lo + hi) / 2
			var w: float = font.get_string_size(line.substr(start, mid), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			if w <= avail:
				fit = mid
				lo = mid + 1
			else:
				hi = mid - 1
		segs.append(line.substr(start, fit))
		start += fit
	return segs

## Prefers breaking between words; any single word still too long for a
## line (no spaces to break on) falls back to a character-level split for
## just that word, same as TextEdit's own boundary mode does.
func _wrap_boundary(line: String, font: Font, fsize: int, avail: float) -> PackedStringArray:
	var space_w: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var words: PackedStringArray = line.split(" ")
	var segs: PackedStringArray = []
	var current: String = ""
	var current_w: float = 0.0
	for w in words:
		var w_width: float = font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		if w_width > avail:
			if current != "":
				segs.append(current)
				current = ""
				current_w = 0.0
			var pieces: PackedStringArray = _wrap_arbitrary(w, font, fsize, avail)
			for p in range(pieces.size() - 1):
				segs.append(pieces[p])
			current = pieces[pieces.size() - 1]
			current_w = font.get_string_size(current, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			continue
		var added_w: float = w_width if current == "" else space_w + w_width
		if current_w + added_w > avail and current != "":
			segs.append(current)
			current = w
			current_w = w_width
		else:
			current = w if current == "" else current + " " + w
			current_w += added_w
	segs.append(current)
	if segs.is_empty():
		segs = [""]
	return segs


func _get_wrapped_segments(line_idx: int) -> PackedStringArray:
	if wrap_mode == WrapMode.NONE:
		return [_lines[line_idx]]
	if _wrap_cache.has(line_idx):
		return _wrap_cache[line_idx]

	var font: Font = _tfont()
	var fsize: int = _tfont_size()
	var avail: float = _content_width()
	var line: String = _lines[line_idx]
	var segs: PackedStringArray

	if wrap_mode == WrapMode.ARBITRARY:
		segs = _wrap_arbitrary(line, font, fsize, avail)
	else:
		segs = _wrap_boundary(line, font, fsize, avail)

	if _wrap_cache.size() > 500:
		_wrap_cache.clear()
	_wrap_cache[line_idx] = segs
	_row_cache[line_idx] = segs.size()
	_avg_rows = lerp(_avg_rows, float(segs.size()), 0.05)
	return segs


# --- drawing -------------------------------------------------------------
func _draw() -> void:
	var normal_style: StyleBox = _tstyle("focus" if has_focus() else "normal")
	if normal_style:
		draw_style_box(normal_style, Rect2(Vector2.ZERO, size))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), _tc("background_color"))

	if _lines.size() == 1 and _lines[0] == "" and placeholder_text != "":
		draw_string(_tfont(), Vector2(padding.x + _gutter_width(), padding.y + _tfont().get_ascent(_tfont_size())),
			placeholder_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _tfont_size(), _tc("font_placeholder_color"))

	var font: Font = _tfont()
	var fsize: int = _tfont_size()
	var ascent: float = font.get_ascent(fsize)
	var descent: float = font.get_descent(fsize)
	var gutter_w: float = _gutter_width()
	var x_scroll: float = _h_scroll.value if wrap_mode == WrapMode.NONE else 0.0

	var start_line: int = int(clamp(_v_scroll.value / (line_height * max(_avg_rows, 0.001)), 0, _lines.size() - 1))
	var y: float = -_row_remainder_offset()

	var occurrences_text: String = get_selected_text() if (highlight_all_occurrences and has_selection()) else ""
	var sel_range: Array = _normalized_selection() if has_selection() else []

	var i: int = start_line
	while i < _lines.size() and y < size.y:
		var segs: PackedStringArray = _get_wrapped_segments(i)

		if highlight_current_line and i == _caret_line and not has_selection():
			draw_rect(Rect2(0, y, size.x - (16 if _v_scroll.visible else 0), line_height * segs.size()), _tc("current_line_color"))

		for seg_idx in range(segs.size()):
			var seg: String = segs[seg_idx]
			var draw_x: float = padding.x + gutter_w - x_scroll

			if not sel_range.is_empty():
				_draw_selection_for_row(i, seg_idx, segs, draw_x, y, font, fsize)

			if occurrences_text != "" and seg.length() >= occurrences_text.length():
				_draw_occurrences(seg, occurrences_text, draw_x, y, font, fsize)

			draw_string(font, Vector2(draw_x, y + ascent), seg, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, _tc("font_color"))

			if seg_idx == 0 and show_line_numbers:
				var num: String = str(i + 1)
				if line_numbers_zero_padded:
					num = num.pad_zeros(str(_lines.size()).length())
				draw_string(font, Vector2(padding.x, y + ascent), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, _tc("line_number_color"))

			if i == _caret_line and _row_contains_caret(segs, seg_idx) and _caret_visible and has_focus() and editable:
				_draw_caret(seg, segs, seg_idx, draw_x, y, ascent, descent, font, fsize)

			y += line_height
			if y > size.y:
				break
		i += 1
		_max_line_width_seen = max(_max_line_width_seen, font.get_string_size(_lines[i - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)


func _row_remainder_offset() -> float:
	return fmod(_v_scroll.value, line_height)

func _row_contains_caret(segs: PackedStringArray, seg_idx: int) -> bool:
	var consumed: int = 0
	for k in range(seg_idx):
		consumed += segs[k].length() + 1
	var seg_end: int = consumed + segs[seg_idx].length()
	if seg_idx == segs.size() - 1:
		return _caret_col >= consumed
	return _caret_col >= consumed and _caret_col <= seg_end

func _draw_caret(seg: String, segs: PackedStringArray, seg_idx: int, draw_x: float, y: float, ascent: float, descent: float, font: Font, fsize: int) -> void:
	var consumed: int = 0
	for k in range(seg_idx):
		consumed += segs[k].length() + 1
	var local_col: int = clamp(_caret_col - consumed, 0, seg.length())
	var cx: float = draw_x + font.get_string_size(seg.substr(0, local_col), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	if caret_type == CaretType.LINE:
		draw_line(Vector2(cx, y), Vector2(cx, y + line_height), _tc("caret_color"), caret_width)
	else:
		var w: float = font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		draw_rect(Rect2(cx, y, w, line_height), _tc("caret_color"))

func _draw_selection_for_row(line_idx: int, seg_idx: int, segs: PackedStringArray, draw_x: float, y: float, font: Font, fsize: int) -> void:
	var a: Array = _normalized_selection()
	var sl: int = a[0]; var sc: int = a[1]; var el: int = a[2]; var ec: int = a[3]
	if line_idx < sl or line_idx > el:
		return
	var consumed: int = 0
	for k in range(seg_idx):
		consumed += segs[k].length() + 1
	var seg: String = segs[seg_idx]
	var row_start: int = consumed
	var row_end: int = consumed + seg.length()
	var from_c: int = sc if line_idx == sl else 0
	var to_c: int = ec if line_idx == el else (row_end + 1)
	from_c = max(from_c, row_start)
	to_c = min(to_c, row_end + (0 if line_idx == el and seg_idx == segs.size() - 1 else 1))
	if from_c > row_end or to_c < row_start:
		return
	var x1: float = draw_x + font.get_string_size(seg.substr(0, max(0, from_c - row_start)), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var x2_col: int = min(seg.length(), max(0, to_c - row_start))
	var x2: float = draw_x + font.get_string_size(seg.substr(0, x2_col), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	if line_idx != el or seg_idx != segs.size() - 1:
		x2 = max(x2, draw_x + 4)
	draw_rect(Rect2(x1, y, max(1.0, x2 - x1), line_height), _tc("selection_color"))

func _draw_occurrences(seg: String, needle: String, draw_x: float, y: float, font: Font, fsize: int) -> void:
	var from: int = 0
	while true:
		var idx: int = seg.find(needle, from)
		if idx == -1:
			break
		var x1: float = draw_x + font.get_string_size(seg.substr(0, idx), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var x2: float = draw_x + font.get_string_size(seg.substr(0, idx + needle.length()), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		draw_rect(Rect2(x1, y, x2 - x1, line_height), _tc("word_highlighted_color"))
		from = idx + needle.length()


func _on_caret_blink() -> void:
	_caret_visible = not _caret_visible
	queue_redraw()

func _after_caret_move() -> void:
	_caret_visible = true
	caret_changed.emit()
	_scroll_caret_into_view()
	queue_redraw()


# --- input -----------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
		return
	if event is InputEventMouseMotion and _dragging:
		_place_caret_from_mouse(event.position, true)
		accept_event()
		return
	if event is InputEventKey and event.pressed:
		_handle_key(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_v_scroll.value -= v_scroll_speed
		accept_event(); return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_v_scroll.value += v_scroll_speed
		accept_event(); return

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if context_menu_enabled:
			grab_focus()
			_menu.position = get_screen_position() + event.position
			_menu.popup()
		accept_event(); return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		grab_focus()
		var now: int = Time.get_ticks_msec()
		if now - _last_click_time < 400 and event.position.distance_to(_last_click_pos) < 6:
			_click_count += 1
		else:
			_click_count = 1
		_last_click_time = now
		_last_click_pos = event.position

		if _click_count == 2:
			_place_caret_from_mouse(event.position, false)
			_select_word_at(_caret_line, _caret_col)
		elif _click_count >= 3:
			select(_caret_line, 0, _caret_line, _lines[_caret_line].length())
		else:
			_place_caret_from_mouse(event.position, event.shift_pressed)
			if selecting_enabled:
				_dragging = true
	else:
		_dragging = false
	accept_event()


func _handle_key(event: InputEventKey) -> void:
	var ctrl: bool = event.is_command_or_control_pressed()
	var shift: bool = event.shift_pressed

	if shortcut_keys_enabled and ctrl:
		match event.keycode:
			KEY_A: select_all(); accept_event(); return
			KEY_C: _copy(); accept_event(); return
			KEY_X:
				if editable: _cut()
				accept_event(); return
			KEY_V:
				if editable: _paste()
				accept_event(); return
			KEY_Z:
				if editable: (redo() if shift else undo())
				accept_event(); return
			KEY_Y:
				if editable: redo()
				accept_event(); return

	match event.keycode:
		KEY_LEFT: _move_horizontal(-1, shift, ctrl)
		KEY_RIGHT: _move_horizontal(1, shift, ctrl)
		KEY_UP: _move_vertical(-1, shift)
		KEY_DOWN: _move_vertical(1, shift)
		KEY_HOME: _move_to_col(0, shift)
		KEY_END: _move_to_col(_lines[_caret_line].length(), shift)
		KEY_PAGEUP: _move_vertical(-int(size.y / line_height), shift)
		KEY_PAGEDOWN: _move_vertical(int(size.y / line_height), shift)
		KEY_BACKSPACE:
			if editable: (_delete_word_before() if ctrl else _delete_before_caret())
		KEY_DELETE:
			if editable: (_delete_word_after() if ctrl else _delete_after_caret())
		KEY_ENTER, KEY_KP_ENTER:
			if editable: insert_text_at_caret("\n")
		KEY_TAB:
			if editable: _handle_tab(shift)
		_:
			if editable and event.unicode > 0 and not ctrl:
				insert_text_at_caret(_validate_text(char(event.unicode)))
	accept_event()


## O(log n) instead of the O(n) linear scan this replaces - each
## get_string_size call reshapes text, so a linear per-character loop is
## actually O(n^2) over a line. Width is monotonic in substring length,
## so binary search is valid here.
func _col_at_x(line: String, target_x: float, font: Font, fsize: int) -> int:
	var lo: int = 0
	var hi: int = line.length()
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		var w: float = font.get_string_size(line.substr(0, mid), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		if w <= target_x:
			lo = mid
		else:
			hi = mid - 1
	var lo_w: float = font.get_string_size(line.substr(0, lo), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var hi_w: float = font.get_string_size(line.substr(0, min(lo + 1, line.length())), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	return lo if abs(lo_w - target_x) <= abs(hi_w - target_x) else min(lo + 1, line.length())


func _place_caret_from_mouse(pos: Vector2, extend_selection: bool) -> void:
	var start_line: int = int(clamp(_v_scroll.value / (line_height * max(_avg_rows, 0.001)), 0, _lines.size() - 1))
	var row: int = int((pos.y + _row_remainder_offset()) / line_height)
	var line_idx: int = clamp(start_line + row, 0, _lines.size() - 1)

	var font: Font = _tfont()
	var fsize: int = _tfont_size()
	var line: String = _lines[line_idx]
	var target_x: float = pos.x - padding.x - _gutter_width() + (_h_scroll.value if wrap_mode == WrapMode.NONE else 0.0)
	var col: int = _col_at_x(line, target_x, font, fsize)

	if extend_selection or _dragging:
		if not _sel_active:
			_sel_active = true
			_sel_anchor_line = _caret_line
			_sel_anchor_col = _caret_col
	else:
		_clear_selection()

	_caret_line = line_idx
	_caret_col = col
	_after_caret_move()


# --- selection helpers -------------------------------------------------
func _clear_selection() -> void:
	_sel_active = false

func _normalized_selection() -> Array:
	if _sel_anchor_line < _caret_line or (_sel_anchor_line == _caret_line and _sel_anchor_col <= _caret_col):
		return [_sel_anchor_line, _sel_anchor_col, _caret_line, _caret_col]
	return [_caret_line, _caret_col, _sel_anchor_line, _sel_anchor_col]

func _select_word_at(line_idx: int, col: int) -> void:
	var line: String = _lines[line_idx]
	var l: int = col
	var r: int = col
	while l > 0 and _is_word_char(line[l - 1]):
		l -= 1
	while r < line.length() and _is_word_char(line[r]):
		r += 1
	select(line_idx, l, line_idx, r)

func _is_word_char(c: String) -> bool:
	return c.is_valid_identifier() or c.strip_edges() != ""


# --- editing -------------------------------------------------------------
func _splice_in(t: String) -> void:
	t = _validate_text(t)
	var insert_lines: PackedStringArray = t.split("\n")
	var before: String = _lines[_caret_line].substr(0, _caret_col)
	var after: String = _lines[_caret_line].substr(_caret_col)

	if insert_lines.size() == 1:
		_lines[_caret_line] = before + insert_lines[0] + after
		_caret_col = before.length() + insert_lines[0].length()
	else:
		insert_lines[0] = before + insert_lines[0]
		var last_idx: int = insert_lines.size() - 1
		insert_lines[last_idx] += after
		var tail: PackedStringArray = _lines.slice(_caret_line + 1)
		_lines.resize(_caret_line)
		_lines.append_array(insert_lines)
		_lines.append_array(tail)
		_caret_line += last_idx
		_caret_col = insert_lines[last_idx].length() - after.length()


func _delete_selection_no_undo() -> void:
	var a: Array = _normalized_selection()
	var sl: int = a[0]; var sc: int = a[1]; var el: int = a[2]; var ec: int = a[3]
	var merged: String = _lines[sl].substr(0, sc) + _lines[el].substr(ec)
	var tail: PackedStringArray = _lines.slice(el + 1)
	_lines.resize(sl)
	_lines.append(merged)
	_lines.append_array(tail)
	_caret_line = sl
	_caret_col = sc
	_clear_selection()

func _delete_before_caret() -> void:
	_push_undo(false)
	if has_selection():
		_delete_selection_no_undo()
	elif _caret_col > 0:
		var line: String = _lines[_caret_line]
		_lines[_caret_line] = line.substr(0, _caret_col - 1) + line.substr(_caret_col)
		_caret_col -= 1
	elif _caret_line > 0:
		var prev_len: int = _lines[_caret_line - 1].length()
		_lines[_caret_line - 1] += _lines[_caret_line]
		_lines.remove_at(_caret_line)
		_caret_line -= 1
		_caret_col = prev_len
	_row_cache.clear(); _wrap_cache.clear()
	_after_edit()

func _delete_after_caret() -> void:
	_push_undo(false)
	if has_selection():
		_delete_selection_no_undo()
	else:
		var line: String = _lines[_caret_line]
		if _caret_col < line.length():
			_lines[_caret_line] = line.substr(0, _caret_col) + line.substr(_caret_col + 1)
		elif _caret_line < _lines.size() - 1:
			_lines[_caret_line] += _lines[_caret_line + 1]
			_lines.remove_at(_caret_line + 1)
	_row_cache.clear(); _wrap_cache.clear()
	_after_edit()

func _delete_word_before() -> void:
	var target_col: int = _word_boundary_left(_caret_line, _caret_col)
	select(_caret_line, target_col, _caret_line, _caret_col)
	_push_undo(false)
	_delete_selection_no_undo()
	_after_edit()

func _delete_word_after() -> void:
	var target_col: int = _word_boundary_right(_caret_line, _caret_col)
	select(_caret_line, _caret_col, _caret_line, target_col)
	_push_undo(false)
	_delete_selection_no_undo()
	_after_edit()

func _handle_tab(shift: bool) -> void:
	var pad: String = " ".repeat(tab_size)
	if has_selection():
		var a: Array = _normalized_selection()
		for i in range(a[0], a[2] + 1):
			if shift:
				var strip_n: int = 0
				while strip_n < tab_size and strip_n < _lines[i].length() and _lines[i][strip_n] == " ":
					strip_n += 1
				_lines[i] = _lines[i].substr(strip_n)
			else:
				_lines[i] = pad + _lines[i]
		_row_cache.clear(); _wrap_cache.clear()
		_after_edit()
	else:
		insert_text_at_caret(pad)


func _after_edit() -> void:
	_max_line_width_seen = max(_max_line_width_seen, _tfont().get_string_size(_lines[_caret_line], HORIZONTAL_ALIGNMENT_LEFT, -1, _tfont_size()).x)
	_update_scrollbars()
	_after_caret_move()
	lines_edited_from.emit(_caret_line, _caret_line)
	text_changed.emit()


# --- navigation ----------------------------------------------------------
func _move_horizontal(dir: int, shift: bool, ctrl: bool) -> void:
	if not shift and has_selection() and not ctrl:
		var a: Array = _normalized_selection()
		_caret_line = a[0] if dir < 0 else a[2]
		_caret_col = a[1] if dir < 0 else a[3]
		_clear_selection()
		_after_caret_move()
		return

	_begin_or_extend_selection(shift)
	if ctrl:
		_caret_col = _word_boundary_left(_caret_line, _caret_col) if dir < 0 else _word_boundary_right(_caret_line, _caret_col)
	else:
		_caret_col += dir
		if _caret_col < 0:
			if _caret_line > 0:
				_caret_line -= 1
				_caret_col = _lines[_caret_line].length()
			else:
				_caret_col = 0
		elif _caret_col > _lines[_caret_line].length():
			if _caret_line < _lines.size() - 1:
				_caret_line += 1
				_caret_col = 0
			else:
				_caret_col = _lines[_caret_line].length()
	if not shift:
		_clear_selection()
	_after_caret_move()

func _move_vertical(delta_lines: int, shift: bool) -> void:
	_begin_or_extend_selection(shift)
	if _caret_wants_x < 0:
		_caret_wants_x = _tfont().get_string_size(_lines[_caret_line].substr(0, _caret_col), HORIZONTAL_ALIGNMENT_LEFT, -1, _tfont_size()).x
	_caret_line = clamp(_caret_line + delta_lines, 0, _lines.size() - 1)
	var font: Font = _tfont()
	var fsize: int = _tfont_size()
	var line: String = _lines[_caret_line]
	_caret_col = _col_at_x(line, _caret_wants_x, font, fsize)
	if not shift:
		_clear_selection()
	_after_caret_move()

func _move_to_col(c: int, shift: bool) -> void:
	_begin_or_extend_selection(shift)
	_caret_col = c
	if not shift:
		_clear_selection()
	_caret_wants_x = -1.0
	_after_caret_move()

func _begin_or_extend_selection(shift: bool) -> void:
	_caret_wants_x = -1.0
	if shift and not _sel_active:
		_sel_active = true
		_sel_anchor_line = _caret_line
		_sel_anchor_col = _caret_col

func _word_boundary_left(line_idx: int, col: int) -> int:
	var line: String = _lines[line_idx]
	var c: int = col
	while c > 0 and not _is_word_char(line[c - 1]):
		c -= 1
	while c > 0 and _is_word_char(line[c - 1]):
		c -= 1
	return c

func _word_boundary_right(line_idx: int, col: int) -> int:
	var line: String = _lines[line_idx]
	var c: int = col
	while c < line.length() and not _is_word_char(line[c]):
		c += 1
	while c < line.length() and _is_word_char(line[c]):
		c += 1
	return c

func _scroll_caret_into_view() -> void:
	var caret_row: float = _caret_line * line_height
	if caret_row < _v_scroll.value:
		_v_scroll.value = caret_row
	elif caret_row + line_height > _v_scroll.value + size.y:
		_v_scroll.value = caret_row + line_height - size.y


# --- clipboard -------------------------------------------------------
func _copy() -> void:
	if has_selection():
		DisplayServer.clipboard_set(get_selected_text())

func _cut() -> void:
	if has_selection():
		DisplayServer.clipboard_set(get_selected_text())
		_push_undo(false)
		_delete_selection_no_undo()
		_after_edit()

func _paste() -> void:
	var raw: String = DisplayServer.clipboard_get()
	if raw != "":
		insert_text_at_caret(raw)


# --- undo/redo: coalesces rapid same-type edits into one snapshot ------
func _push_undo(is_insert: bool) -> void:
	var now: int = Time.get_ticks_msec()
	if _undo_stack.size() > 0 and is_insert == _last_edit_was_insert and now - _last_undo_push_msec < 400:
		return
	_undo_stack.append({"lines": _lines.duplicate(), "line": _caret_line, "col": _caret_col})
	if _undo_stack.size() > 200:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_last_undo_push_msec = now
	_last_edit_was_insert = is_insert

func _apply_history(from_stack: Array, to_stack: Array) -> void:
	if from_stack.is_empty():
		return
	to_stack.append({"lines": _lines.duplicate(), "line": _caret_line, "col": _caret_col})
	var state: Dictionary = from_stack.pop_back()
	_lines = state["lines"]
	_caret_line = state["line"]
	_caret_col = state["col"]
	_row_cache.clear(); _wrap_cache.clear()
	_update_scrollbars()
	_after_caret_move()
	text_changed.emit()


func _on_menu_id_pressed(id: int) -> void:
	match id:
		0: _cut()
		1: _copy()
		2: _paste()
		3: select_all()
		4: undo()
		5: redo()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_EXIT and deselect_on_focus_loss_enabled:
		deselect()
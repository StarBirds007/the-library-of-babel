extends Node

var json_file_path: String = "user://saved_addresses.json"
var access: FileAccess


func load_addresses() -> Array:
	var saved_addresses: Array = []

	if not FileAccess.file_exists(json_file_path):
		_clear_file()

	access = FileAccess.open(json_file_path, FileAccess.READ)
	if access:
		var parsed = JSON.parse_string(access.get_as_text())

		if typeof(parsed) == TYPE_ARRAY:
			saved_addresses = parsed
		else:
			_clear_file()
			saved_addresses = load_addresses()

		access.close()
	else:
		assert(false, "Open error: %d Failed to open file for reading: %s" % [error_string(FileAccess.get_open_error()), json_file_path])
	
	return saved_addresses


func _clear_file() -> void:
	access = FileAccess.open(json_file_path, FileAccess.WRITE)
	if access:
		access.store_string("[\n]")
		access.close()
	else:
		assert(false, "Open error: %d Failed to open file for writing: %s" % [error_string(FileAccess.get_open_error()), json_file_path])


func add_address(address: Dictionary) -> void:
	var array_size = load_addresses().size()
	access = FileAccess.open(json_file_path, FileAccess.READ_WRITE)

	if access:
		access.seek_end(-1)
		print("Access Position: %d" % access.get_position())
		if array_size == 0:
			access.store_string(JSON.stringify(address) + "\n]")
		else:
			access.store_string("," + JSON.stringify(address) + "\n]")
		access.close()
	else:
		assert(false, "Open error: %d Failed to open file for writing: %s" % [error_string(FileAccess.get_open_error()), json_file_path])


func delete_address(index: int) -> void:
	var saved_addresses: Array = load_addresses()
	if index >= 0 and index < saved_addresses.size():
		saved_addresses.remove_at(index)

		_clear_file()
		access = FileAccess.open(json_file_path, FileAccess.READ_WRITE)
		access.seek_end(-1)

		if access:
			for i in range(saved_addresses.size() - 1):
				access.store_string(JSON.stringify(saved_addresses[i]) + ",\n")
			access.store_string(JSON.stringify(saved_addresses[saved_addresses.size() - 1]) + "\n]")
			access.close()
	else:
		assert(false, "Invalid index: %d. Cannot delete address." % index)
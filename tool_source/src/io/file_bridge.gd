class_name FileBridge
extends Node

signal model_loaded(filename: String, content: String)
signal texture_loaded(filename: String, image: Image)
signal load_error(message: String)
signal save_complete(filename: String)
signal save_error(message: String)

const MODEL_ACCEPT := ".obj,.blueprint"
const TEXTURE_ACCEPT := ".png,.jpg,.jpeg,.webp,.bmp"

var _is_web: bool = false

# prevent garbage collection of JS callbacks
var _model_callback: JavaScriptObject
var _texture_callback: JavaScriptObject


func _ready() -> void:
	_is_web = OS.has_feature("web")
	if _is_web:
		_setup_web()


# === #
# API #
# === #

func request_model() -> void:
	if _is_web:
		_open_web_picker(MODEL_ACCEPT, "_godot_model_cb")
	else:
		_open_desktop_dialog(
			["*.obj ; OBJ Models", "*.blueprint ; Blueprint Files"],
			_on_desktop_model_selected
		)


func request_texture() -> void:
	if _is_web:
		_open_web_image_picker(TEXTURE_ACCEPT, "_godot_texture_cb")
	else:
		_open_desktop_dialog(
			["*.png ; PNG Images", "*.jpg ; JPG Images", "*.jpeg ; JPEG Images", "*.webp ; WebP Images"],
			_on_desktop_texture_selected
		)

func save_text(filename: String, content: String) -> void:
	if _is_web:
		_save_web_text(filename, content)
	else:
		_save_desktop_text(filename, content)


# ===================== #
# Web — JavaScriptBridge #
# ===================== #

func _setup_web() -> void:
	_model_callback = JavaScriptBridge.create_callback(_on_web_model_result)
	_texture_callback = JavaScriptBridge.create_callback(_on_web_texture_result)

	var window := JavaScriptBridge.get_interface("window")
	window["_godot_model_cb"] = _model_callback
	window["_godot_texture_cb"] = _texture_callback

	JavaScriptBridge.eval("""
		window._godotPickFile = function(accept, callbackKey) {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = accept;
			input.style.display = 'none';
			document.body.appendChild(input);

			input.addEventListener('change', function() {
				var file = input.files[0];
				if (!file) { document.body.removeChild(input); return; }

				var reader = new FileReader();
				reader.onload = function(e) {
					var cb = window[callbackKey];
					if (cb) cb(file.name, e.target.result);
				};

				reader.readAsText(file);
				document.body.removeChild(input);
			});

			input.click();
		};

		window._godotPickImageFile = function(accept, callbackKey) {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = accept;
			input.style.display = 'none';
			document.body.appendChild(input);

			input.addEventListener('change', function() {
				var file = input.files[0];
				if (!file) { document.body.removeChild(input); return; }

				var reader = new FileReader();
				reader.onload = function(e) {
					var cb = window[callbackKey];
					if (cb) cb(file.name, e.target.result);
				};

				reader.readAsDataURL(file);
				document.body.removeChild(input);
			});

			input.click();
		};

		window._godotSaveFile = function(filename, content) {
			var blob = new Blob([content], { type: 'application/octet-stream' });
			var url = URL.createObjectURL(blob);
			var a = document.createElement('a');
			a.href = url;
			a.download = filename;
			a.style.display = 'none';
			document.body.appendChild(a);
			a.click();
			document.body.removeChild(a);
			URL.revokeObjectURL(url);
		};
	""", true)


func _open_web_picker(accept: String, callback_key: String) -> void:
	JavaScriptBridge.eval(
		"window._godotPickFile('%s', '%s');" % [accept, callback_key],
		true
	)


func _open_web_image_picker(accept: String, callback_key: String) -> void:
	JavaScriptBridge.eval(
		"window._godotPickImageFile('%s', '%s');" % [accept, callback_key],
		true
	)


func _save_web_text(filename: String, content: String) -> void:
	# Escape backticks and backslashes in content for JS template literal
	var escaped := content.replace("\\", "\\\\").replace("`", "\\`").replace("$", "\\$")
	JavaScriptBridge.eval(
		"window._godotSaveFile(`%s`, `%s`);" % [filename, escaped],
		true
	)
	save_complete.emit(filename)


func _on_web_model_result(args: Array) -> void:
	var filename := str(args[0])
	var content := str(args[1])
	if content.is_empty():
		load_error.emit("File was empty: " + filename)
		return
	model_loaded.emit(filename, content)


func _on_web_texture_result(args: Array) -> void:
	var filename := str(args[0])
	var data_url := str(args[1])

	var image := _decode_data_url(filename, data_url)
	if image == null:
		return
	texture_loaded.emit(filename, image)


func _decode_data_url(filename: String, data_url: String) -> Image:
	var split := data_url.split(",")

	if split.size() < 2:
		load_error.emit("Invalid image data for: " + filename)
		return null

	var bytes := Marshalls.base64_to_raw(split[1])
	if bytes.is_empty():
		load_error.emit("Failed to decode image: " + filename)
		return null

	var image := Image.new()
	var ext := filename.get_extension().to_lower()
	var err: Error

	match ext:
		"png":
			err = image.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			err = image.load_jpg_from_buffer(bytes)
		"webp":
			err = image.load_webp_from_buffer(bytes)
		"bmp":
			err = image.load_bmp_from_buffer(bytes)
		_:
			load_error.emit("Unsupported image format: " + ext)
			return null

	if err != OK:
		load_error.emit("Failed to parse image: " + filename)
		return null

	return image


# =============================#
# Desktop  (editor only)       #
# =============================#

func _open_desktop_dialog(filters: PackedStringArray, callback: Callable) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = filters
	dialog.size = Vector2i(800, 500)

	dialog.file_selected.connect(func(path: String) -> void:
		callback.call(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()


func _on_desktop_model_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_error.emit("Could not open file: " + path)
		return

	var content := file.get_as_text()
	file.close()
	model_loaded.emit(path.get_file(), content)


func _on_desktop_texture_selected(path: String) -> void:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		load_error.emit("Could not load image: " + path)
		return
	texture_loaded.emit(path.get_file(), image)


func _save_desktop_text(filename: String, content: String) -> void:
	var ext := filename.get_extension().to_lower()
	var filters: PackedStringArray
	match ext:
		"obj":
			filters = ["*.obj ; OBJ Models"]
		"blueprint":
			filters = ["*.blueprint ; Blueprint Files"]
		_:
			filters = ["*.*"]

	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = filters
	dialog.current_file = filename
	dialog.size = Vector2i(800, 500)

	dialog.file_selected.connect(func(path: String) -> void:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			save_error.emit("Could not write file: " + path)
			dialog.queue_free()
			return
		file.store_string(content)
		file.close()
		save_complete.emit(path.get_file())
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()

extends Control

# ===================== #
# Preview page nodes    #
# ===================== #
@onready var cube: MeshInstance3D = $Pages/Preview/HSplitContainer/LeftPanel/SubViewportContainer/SubViewport/World/MeshInstance3D
@onready var world: Node3D = $Pages/Preview/HSplitContainer/LeftPanel/SubViewportContainer/SubViewport/World
@onready var preview_model_line_edit: LineEdit = $Pages/Preview/HSplitContainer/RightPanel/MarginContainer/VSplitContainer/Upper/ModelLoad/LineEdit
@onready var preview_load_btn: Button = $Pages/Preview/HSplitContainer/RightPanel/MarginContainer/VSplitContainer/Upper/ModelLoad/Load
@onready var preview_texture_line_edit: LineEdit = $Pages/Preview/HSplitContainer/RightPanel/MarginContainer/VSplitContainer/Upper/TextureLoad/LineEdit
@onready var preview_texture_load_btn: Button = $Pages/Preview/HSplitContainer/RightPanel/MarginContainer/VSplitContainer/Upper/TextureLoad/Load
@onready var texture_preview_rect: TextureRect = $Pages/Preview/HSplitContainer/RightPanel/MarginContainer/VSplitContainer/Upper/TexturePreview

# ========================== #
# File Conversion page nodes #
# ========================== #
@onready var input_line_edit: LineEdit = $"Pages/File Conversion/MarginContainer/VBoxContainer/Input/LineEdit"
@onready var input_browse_btn: Button = $"Pages/File Conversion/MarginContainer/VBoxContainer/Input/Browse"
@onready var output_line_edit: LineEdit = $"Pages/File Conversion/MarginContainer/VBoxContainer/Output/LineEdit"
@onready var convert_btn: Button = $"Pages/File Conversion/MarginContainer/VBoxContainer/Convert"


# ============== #
# Interactive UI #
# ============== #
@onready var gear : Sprite2D = $"Pages/File Conversion/Gear"
@onready var gear_animation_player = $"Pages/File Conversion/Gear/AnimationPlayer"

# ============ #
# State        #
# ============ #
var file_bridge: FileBridge
var _loaded_mesh: MeshInstance3D = null
var _loaded_texture: ImageTexture = null


var _current_mesh_data: MeshData = null
var _conversion_filename: String = ""

enum LoadTarget { PREVIEW, CONVERSION }
var _pending_target: LoadTarget = LoadTarget.PREVIEW


func _ready() -> void:
	_setup_file_bridge()
	_connect_signals()
	_configure_ui()
	
	gear_animation_player.play("spin")


# ============ #
# Setup        #
# ============ #

func _setup_file_bridge() -> void:
	file_bridge = FileBridge.new()
	file_bridge.name = "FileBridge"
	add_child(file_bridge)

	file_bridge.model_loaded.connect(_on_model_loaded)
	file_bridge.load_error.connect(_on_load_error)
	file_bridge.texture_loaded.connect(_on_texture_loaded)
	file_bridge.save_complete.connect(_on_save_complete)
	file_bridge.save_error.connect(_on_save_error)


func _connect_signals() -> void:
	preview_load_btn.pressed.connect(_on_preview_load_pressed)
	input_browse_btn.pressed.connect(_on_conversion_browse_pressed)
	convert_btn.pressed.connect(_on_convert_pressed)
	preview_texture_load_btn.pressed.connect(_on_preview_texture_load_pressed)


func _configure_ui() -> void:
	preview_model_line_edit.editable = false
	preview_model_line_edit.placeholder_text = "No model loaded"

	input_line_edit.editable = false
	input_line_edit.placeholder_text = "No file selected"

	output_line_edit.editable = false
	output_line_edit.placeholder_text = "—"

	convert_btn.disabled = true

	preview_texture_line_edit.editable = false
	preview_texture_line_edit.placeholder_text = "No texture loaded"


# ================ #
# Button handlers  #
# ================ #
func _on_preview_texture_load_pressed() -> void:
	file_bridge.request_texture()


func _on_preview_load_pressed() -> void:
	_pending_target = LoadTarget.PREVIEW
	file_bridge.request_model()


func _on_conversion_browse_pressed() -> void:
	_pending_target = LoadTarget.CONVERSION
	file_bridge.request_model()


func _on_convert_pressed() -> void:
	if _current_mesh_data == null:
		return

	var src_ext := _conversion_filename.get_extension().to_lower()
	var base_name := _conversion_filename.get_basename()

	var output_text: String
	var output_filename: String

	match src_ext:
		"obj":
			output_text = BlueprintBuilder.build(_current_mesh_data, base_name)
			output_filename = base_name + ".blueprint"
		"blueprint":
			output_text = OBJBuilder.build(_current_mesh_data, base_name)
			output_filename = base_name + ".obj"
		_:
			push_warning("main: Cannot convert from ." + src_ext)
			return

	file_bridge.save_text(output_filename, output_text)


# ================ #
# File loaded      #
# ================ #
func _on_texture_loaded(filename: String, image: Image) -> void:
	_loaded_texture = ImageTexture.create_from_image(image)
	texture_preview_rect.texture = _loaded_texture
	preview_texture_line_edit.text = filename
	_apply_texture_to_mesh()


func _on_model_loaded(filename: String, content: String) -> void:
	var ext := filename.get_extension().to_lower()
	var md := _parse(content, ext)

	match _pending_target:
		LoadTarget.PREVIEW:
			if md:
				_display_mesh_data(md)
				preview_model_line_edit.text = filename
			else:
				preview_model_line_edit.text = "Failed to load: " + filename

		LoadTarget.CONVERSION:
			input_line_edit.text = filename
			if md:
				_current_mesh_data = md
				_conversion_filename = filename
				_display_mesh_data(md)
				preview_model_line_edit.text = filename
				_update_output_label(ext)
				convert_btn.disabled = false
			else:
				_current_mesh_data = null
				_conversion_filename = ""
				output_line_edit.text = "Parse failed"
				convert_btn.disabled = true


func _parse(content: String, ext: String) -> MeshData:
	match ext:
		"obj":
			return OBJParser.parse(content)
		"blueprint":
			return BlueprintParser.parse(content)
		_:
			push_warning("main: Unsupported file extension: " + ext)
			return null


func _update_output_label(input_ext: String) -> void:
	match input_ext:
		"obj":
			output_line_edit.text = "→ .blueprint"
		"blueprint":
			output_line_edit.text = "→ .obj"
		_:
			output_line_edit.text = "Unknown"


# ================ #
# Mesh display     #
# ================ #

func _display_mesh_data(md: MeshData) -> void:
	var mesh := md.to_array_mesh()
	if mesh == null:
		push_warning("main: MeshData produced no renderable mesh")
		return
	_display_mesh(mesh)


func _display_mesh(mesh: ArrayMesh) -> void:
	cube.visible = false

	if _loaded_mesh != null:
		_loaded_mesh.queue_free()
		_loaded_mesh = null

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3.ZERO

	world.add_child(instance)
	_loaded_mesh = instance

	_apply_texture_to_mesh()


func _apply_texture_to_mesh() -> void:
	if _loaded_mesh == null or _loaded_texture == null:
		return
	var mat := StandardMaterial3D.new()
	mat.uv1_triplanar = true  # temp fix for no UVs, add proper UV parsing
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Make new base material that swaps albedo textures instead
	mat.albedo_texture = _loaded_texture
	_loaded_mesh.set_surface_override_material(0, mat)


# ================ #
# Save callbacks   #
# ================ #

func _on_save_complete(filename: String) -> void:
	output_line_edit.text = "Saved: " + filename


func _on_save_error(message: String) -> void:
	output_line_edit.text = "Save failed: " + message


# ================ #
# Error handling   #
# ================ #

func _on_load_error(message: String) -> void:
	push_warning("FileBridge error: " + message)
	match _pending_target:
		LoadTarget.PREVIEW:
			preview_model_line_edit.text = "Error: " + message
		LoadTarget.CONVERSION:
			input_line_edit.text = "Error: " + message

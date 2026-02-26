class_name BlueprintParser
extends RefCounted

static func parse(blueprint_text: String) -> MeshData:
	var json := JSON.new()
	if json.parse(blueprint_text) != OK:
		push_warning("BlueprintParser: Failed to parse JSON")
		return null

	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("BlueprintParser: Root is not a dictionary")
		return null

	if not data.has("v") or data["v"] != "0.2":
		push_warning("BlueprintParser: Unsupported or missing version (expected 0.2, got %s)" % str(data.get("v", "none")))
		return null

	# Reject vehicle blueprints
	if data.has("header") and data.has("blueprints"):
		push_warning("BlueprintParser: Vehicle blueprints are not supported — only standard v0.2 mesh blueprints")
		return null

	if not data.has("mesh"):
		push_warning("BlueprintParser: No mesh key found")
		return null

	var mesh_block: Dictionary = data["mesh"]

	if not mesh_block.has("vertices") or not mesh_block.has("faces"):
		push_warning("BlueprintParser: mesh is missing vertices or faces")
		return null

	# ======================== #
	# Build vertex array       #
	# ======================== #
	var flat: Array = mesh_block["vertices"]
	var verts := PackedVector3Array()
	for i in range(0, flat.size() - 2, 3):
		verts.append(Vector3(
			-float(flat[i]),
			 float(flat[i + 1]),
			 float(flat[i + 2])
		))

	if verts.is_empty():
		push_warning("BlueprintParser: No vertices found")
		return null

	# ======================== #
	# Build faces (preserved)  #
	# ======================== #
	var parsed_faces: Array[PackedInt32Array] = []
	var face_extras: Array[Dictionary] = []  # per-face t/tm/te
	var raw_faces: Array = mesh_block["faces"]

	var tri_count := 0
	var quad_count := 0

	for face in raw_faces:
		if not face.has("v"):
			continue
		var v_arr: Array = face["v"]
		if v_arr.size() < 3:
			continue

		var idx := PackedInt32Array()
		for v in v_arr:
			idx.append(int(v))
		parsed_faces.append(idx)

		if v_arr.size() == 3:
			tri_count += 1
		elif v_arr.size() == 4:
			quad_count += 1

		# Preserve blueprint-specific face attributes
		var extras := {}
		if face.has("t"):
			extras["t"] = face["t"]
		if face.has("tm"):
			extras["tm"] = face["tm"]
		if face.has("te"):
			extras["te"] = face["te"]
		face_extras.append(extras)

	if parsed_faces.is_empty():
		push_warning("BlueprintParser: No valid faces found")
		return null

	# ======================== #
	# Assemble MeshData        #
	# ======================== #
	var md := MeshData.new()
	md.vertices = verts
	md.faces = parsed_faces
	md.source_format = "blueprint"

	# Store everything needed for faithful blueprint rebuild
	md.metadata["name"] = data.get("name", "")
	md.metadata["smoothAngle"] = data.get("smoothAngle", 0)
	md.metadata["gridSize"] = data.get("gridSize", 1)
	md.metadata["format"] = data.get("format", "freeform")
	md.metadata["mesh_major_version"] = mesh_block.get("majorVersion", 0)
	md.metadata["mesh_minor_version"] = mesh_block.get("minorVersion", 3)
	md.metadata["face_extras"] = face_extras

	# Preserve edges/edgeFlags
	if mesh_block.has("edges"):
		md.metadata["edges"] = mesh_block["edges"]
	if mesh_block.has("edgeFlags"):
		md.metadata["edgeFlags"] = mesh_block["edgeFlags"]

	# Preserve rivets section
	if data.has("rivets"):
		md.metadata["rivets"] = data["rivets"]

	print("BlueprintParser: Loaded %d vertices, %d tris, %d quads (topology preserved)" % [
		verts.size(), tri_count, quad_count
	])

	return md

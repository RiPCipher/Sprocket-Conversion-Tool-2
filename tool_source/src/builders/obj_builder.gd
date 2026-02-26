class_name OBJBuilder
extends RefCounted

static func build(md: MeshData, name_override: String = "") -> String:
	var lines: PackedStringArray = PackedStringArray()

	# Header
	var obj_name: String
	if not name_override.is_empty():
		obj_name = name_override
	elif md.metadata.has("name") and not str(md.metadata["name"]).is_empty():
		obj_name = md.metadata["name"]
	else:
		obj_name = "exported_mesh"

	lines.append("# OBJ exported by Blueprint Tool")
	lines.append("o %s" % obj_name)

	# ==========#
	# Vertices  #
	# ========= #
	for v in md.vertices:
		lines.append("v %.6f %.6f %.6f" % [v.x, v.y, v.z])

	# ======================== #
	# Determine data sources   #
	# ======================== #
	var has_existing_normals := (md.normals.size() > 0 and md.face_normal_indices.size() == md.faces.size())
	var has_existing_uvs := (md.uvs.size() > 0 and md.face_uv_indices.size() == md.faces.size())

	var gen_normals: PackedVector3Array
	var gen_uvs: Array[PackedVector2Array]

	if not has_existing_normals or not has_existing_uvs:
		gen_normals = MeshGen.generate_flat_normals(md.vertices, md.faces)
	if not has_existing_uvs:
		gen_uvs = MeshGen.generate_box_uvs(md.vertices, md.faces, gen_normals)

	# ========#
	# Normals #
	# ========#
	if has_existing_normals:
		for n in md.normals:
			lines.append("vn %.6f %.6f %.6f" % [n.x, n.y, n.z])
	else:
		for n in gen_normals:
			lines.append("vn %.6f %.6f %.6f" % [n.x, n.y, n.z])

	# ====#
	# UVs #
	# ====#
	if has_existing_uvs:
		for uv in md.uvs:
			lines.append("vt %.6f %.6f" % [uv.x, 1.0 - uv.y])
	else:
		for fi in range(md.faces.size()):
			for ci in range(md.faces[fi].size()):
				var uv := gen_uvs[fi][ci]
				lines.append("vt %.6f %.6f" % [uv.x, uv.y])

	# ======================== #
	# Faces                    #
	# ======================== #
	if has_existing_normals and has_existing_uvs:
		for fi in range(md.faces.size()):
			var face := md.faces[fi]
			var tokens: PackedStringArray = PackedStringArray()
			tokens.append("f")
			for ci in range(face.size()):
				var v_obj := face[ci] + 1
				var uv_obj := md.face_uv_indices[fi][ci] + 1
				var n_obj := md.face_normal_indices[fi][ci] + 1
				tokens.append("%d/%d/%d" % [v_obj, uv_obj, n_obj])
			lines.append(" ".join(tokens))

	elif has_existing_uvs:
		for fi in range(md.faces.size()):
			var face := md.faces[fi]
			var tokens: PackedStringArray = PackedStringArray()
			tokens.append("f")
			var n_obj := fi + 1
			for ci in range(face.size()):
				var v_obj := face[ci] + 1
				var uv_obj := md.face_uv_indices[fi][ci] + 1
				tokens.append("%d/%d/%d" % [v_obj, uv_obj, n_obj])
			lines.append(" ".join(tokens))

	elif has_existing_normals:
		var uv_counter := 1
		for fi in range(md.faces.size()):
			var face := md.faces[fi]
			var tokens: PackedStringArray = PackedStringArray()
			tokens.append("f")
			for ci in range(face.size()):
				var v_obj := face[ci] + 1
				var n_obj := md.face_normal_indices[fi][ci] + 1
				tokens.append("%d/%d/%d" % [v_obj, uv_counter, n_obj])
				uv_counter += 1
			lines.append(" ".join(tokens))

	else:
		var uv_counter := 1
		for fi in range(md.faces.size()):
			var face := md.faces[fi]
			var tokens: PackedStringArray = PackedStringArray()
			tokens.append("f")
			var n_obj := fi + 1
			for ci in range(face.size()):
				var v_obj := face[ci] + 1
				tokens.append("%d/%d/%d" % [v_obj, uv_counter, n_obj])
				uv_counter += 1
			lines.append(" ".join(tokens))

	return "\n".join(lines) + "\n"

class_name OBJParser
extends RefCounted

static func parse(obj_text: String) -> MeshData:
	var raw_vertices: PackedVector3Array = PackedVector3Array()
	var raw_normals: PackedVector3Array = PackedVector3Array()
	var raw_uvs: PackedVector2Array = PackedVector2Array()

	var parsed_faces: Array[PackedInt32Array] = []
	var parsed_face_normal_indices: Array[PackedInt32Array] = []
	var parsed_face_uv_indices: Array[PackedInt32Array] = []

	var has_normals := false
	var has_uvs := false

	var tri_count := 0
	var quad_count := 0
	var ngon_count := 0

	for line in obj_text.split("\n"):
		line = line.strip_edges()

		if line.is_empty() or line[0] == '#':
			continue

		if line.begins_with("v "):
			var parts := line.split(" ", false)
			if parts.size() >= 4:
				raw_vertices.append(Vector3(
					float(parts[1]),
					float(parts[2]),
					float(parts[3])
				))

		elif line.begins_with("vn "):
			var parts := line.split(" ", false)
			if parts.size() >= 4:
				raw_normals.append(Vector3(
					float(parts[1]),
					float(parts[2]),
					float(parts[3])
				))

		elif line.begins_with("vt "):
			var parts := line.split(" ", false)
			if parts.size() >= 3:
				raw_uvs.append(Vector2(
					float(parts[1]),
					1.0 - float(parts[2])  # flip V for Godot
				))

		elif line.begins_with("f "):
			var parts := line.split(" ", false)

			var face_v := PackedInt32Array()
			var face_n := PackedInt32Array()
			var face_uv := PackedInt32Array()

			for i in range(1, parts.size()):
				var token := parts[i]
				var indices := token.split("/")

				# Vertex index
				var v_idx := int(indices[0])
				if v_idx < 0:
					v_idx = raw_vertices.size() + v_idx + 1
				face_v.append(v_idx - 1)

				# UV index
				var uv_idx := -1
				if indices.size() > 1 and not indices[1].is_empty():
					uv_idx = int(indices[1])
					if uv_idx < 0:
						uv_idx = raw_uvs.size() + uv_idx + 1
					uv_idx -= 1
					has_uvs = true
				face_uv.append(uv_idx)

				# Normal index
				var n_idx := -1
				if indices.size() > 2 and not indices[2].is_empty():
					n_idx = int(indices[2])
					if n_idx < 0:
						n_idx = raw_normals.size() + n_idx + 1
					n_idx -= 1
					has_normals = true
				face_n.append(n_idx)

			if face_v.size() < 3:
				continue

			parsed_faces.append(face_v)
			parsed_face_normal_indices.append(face_n)
			parsed_face_uv_indices.append(face_uv)

			match face_v.size():
				3: tri_count += 1
				4: quad_count += 1
				_: ngon_count += 1

	if raw_vertices.is_empty() or parsed_faces.is_empty():
		push_warning("OBJParser: No geometry found in file")
		return null

	# ======================== #
	# Assemble MeshData        #
	# ======================== #
	var md := MeshData.new()
	md.vertices = raw_vertices
	md.faces = parsed_faces
	md.source_format = "obj"

	if has_normals:
		md.normals = raw_normals
		md.face_normal_indices = parsed_face_normal_indices

	if has_uvs:
		md.uvs = raw_uvs
		md.face_uv_indices = parsed_face_uv_indices

	print("OBJParser: Loaded %d vertices, %d tris, %d quads, %d ngons (topology preserved)" % [
		raw_vertices.size(), tri_count, quad_count, ngon_count
	])

	return md

class_name MeshData
extends RefCounted

# ============ #
# Core geometry #
# ============ #
var vertices: PackedVector3Array = PackedVector3Array()
var faces: Array[PackedInt32Array] = []

# ============#
# attributes  #
# =========== #
var normals: PackedVector3Array = PackedVector3Array()
var uvs: PackedVector2Array = PackedVector2Array()
var face_normal_indices: Array[PackedInt32Array] = []
var face_uv_indices: Array[PackedInt32Array] = []

# ==================== #
# Format-specific data  #
# ==================== #
var source_format: String = ""
var metadata: Dictionary = {}


# ================ #
# Topology queries  #
# ================ #

func get_face_count() -> int:
	return faces.size()


func get_vertex_count() -> int:
	return vertices.size()


func get_triangle_count() -> int:
	var count := 0
	for face in faces:
		if face.size() == 3:
			count += 1
	return count


func get_quad_count() -> int:
	var count := 0
	for face in faces:
		if face.size() == 4:
			count += 1
	return count


func get_ngon_count() -> int:
	var count := 0
	for face in faces:
		if face.size() > 4:
			count += 1
	return count


# ========= #
# Rendering #
# ========= #
func to_array_mesh() -> ArrayMesh:
	if vertices.is_empty() or faces.is_empty():
		return null

	var has_existing_normals := (normals.size() > 0 and face_normal_indices.size() == faces.size())
	var has_existing_uvs := (uvs.size() > 0 and face_uv_indices.size() == faces.size())

	var flat_normals: PackedVector3Array
	var box_uvs: Array[PackedVector2Array]

	if not has_existing_normals or not has_existing_uvs:
		flat_normals = MeshGen.generate_flat_normals(vertices, faces, source_format == "blueprint")
	if not has_existing_uvs:
		box_uvs = MeshGen.generate_box_uvs(vertices, faces, flat_normals)

	# Exploded arrays
	var out_verts := PackedVector3Array()
	var out_norms := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var out_indices := PackedInt32Array()

	var vert_offset := 0

	for fi in range(faces.size()):
		var face := faces[fi]
		var n := face.size()
		if n < 3:
			continue

		# Emit one exploded vertex per face corner
		for ci in range(n):
			out_verts.append(vertices[face[ci]])

			# Normal
			if has_existing_normals:
				out_norms.append(normals[face_normal_indices[fi][ci]])
			else:
				out_norms.append(flat_normals[fi])

			# UV
			if has_existing_uvs:
				out_uvs.append(uvs[face_uv_indices[fi][ci]])
			else:
				out_uvs.append(box_uvs[fi][ci])

		for i in range(1, n - 1):
			out_indices.append(vert_offset)
			out_indices.append(vert_offset + i)
			out_indices.append(vert_offset + i + 1)

		vert_offset += n

	if out_indices.is_empty():
		return null

	var surface_arrays := []
	surface_arrays.resize(Mesh.ARRAY_MAX)
	surface_arrays[Mesh.ARRAY_VERTEX] = out_verts
	surface_arrays[Mesh.ARRAY_NORMAL] = out_norms
	surface_arrays[Mesh.ARRAY_TEX_UV] = out_uvs
	surface_arrays[Mesh.ARRAY_INDEX] = out_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)

	return mesh

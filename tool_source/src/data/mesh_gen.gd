class_name MeshGen
extends RefCounted

static func generate_flat_normals(
	vertices: PackedVector3Array,
	faces: Array[PackedInt32Array],
	flip: bool = false
) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(faces.size())

	for i in range(faces.size()):
		var face := faces[i]
		if face.size() < 3:
			normals[i] = Vector3.UP
			continue

		var v0 := vertices[face[0]]
		var v1 := vertices[face[1]]
		var v2 := vertices[face[2]]

		var edge1 := v1 - v0
		var edge2 := v2 - v0
		var n := edge1.cross(edge2).normalized()

		if flip:
			n = -n

		if n.is_zero_approx():
			n = Vector3.UP

		normals[i] = n

	return normals

static func generate_box_uvs(
	vertices: PackedVector3Array,
	faces: Array[PackedInt32Array],
	face_normals: PackedVector3Array
) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	result.resize(faces.size())

	for i in range(faces.size()):
		var face := faces[i]
		var n := face_normals[i]
		var abs_n := n.abs()

		var face_uvs := PackedVector2Array()
		face_uvs.resize(face.size())

		for ci in range(face.size()):
			var v := vertices[face[ci]]
			var uv: Vector2
			if abs_n.x >= abs_n.y and abs_n.x >= abs_n.z:
				uv = Vector2(v.z, v.y)
			elif abs_n.y >= abs_n.x and abs_n.y >= abs_n.z:
				uv = Vector2(v.x, v.z)
			else:
				uv = Vector2(v.x, v.y)

			face_uvs[ci] = uv

		result[i] = face_uvs

	return result

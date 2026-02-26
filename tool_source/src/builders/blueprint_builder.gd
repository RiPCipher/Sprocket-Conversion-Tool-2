class_name BlueprintBuilder
extends RefCounted

static func build(md: MeshData, name_override: String = "") -> String:
	var is_round_trip := (md.source_format == "blueprint")

	# ======================== #
	# Blueprint name           #
	# ======================== #
	var bp_name: String
	if not name_override.is_empty():
		bp_name = name_override
	elif md.metadata.has("name") and not str(md.metadata["name"]).is_empty():
		bp_name = md.metadata["name"]
	else:
		bp_name = "Exported Mesh"

	# ======================== #
	# Vertices (negate X back) #
	# ======================== #
	var vertex_array: Array = []
	for v in md.vertices:
		vertex_array.append(-v.x)  # negate X back to blueprint
		vertex_array.append(v.y)
		vertex_array.append(v.z)

	# ======================== #
	# Edges from face topology #
	# ======================== #
	var edges: Array
	var edge_flags: Array

	if is_round_trip and md.metadata.has("edges") and md.metadata.has("edgeFlags"):
		edges = md.metadata["edges"]
		edge_flags = md.metadata["edgeFlags"]
	else:
		var edge_result := _build_edges_from_faces(md.faces)
		edges = edge_result[0]
		edge_flags = edge_result[1]

	# ======================== #
	# Face data assembly       #
	# ======================== #
	var face_extras: Array = md.metadata.get("face_extras", [])

	# ======================== #
	# Rivets                   #
	# ======================== #
	var rivets_profiles: Array = []
	var rivets_nodes: Array = []
	if md.metadata.has("rivets"):
		var rivets_data: Dictionary = md.metadata["rivets"]
		if rivets_data.has("profiles"):
			rivets_profiles = rivets_data["profiles"]
		if rivets_data.has("nodes"):
			rivets_nodes = rivets_data["nodes"]

	# ======================== #
	# Metadata values          #
	# ======================== #
	var smooth_angle: int = int(md.metadata.get("smoothAngle", 0))
	var grid_size: int = int(md.metadata.get("gridSize", 1))
	var bp_format: String = md.metadata.get("format", "freeform")
	var mesh_major: int = int(md.metadata.get("mesh_major_version", 0))
	var mesh_minor: int = int(md.metadata.get("mesh_minor_version", 3))

	
	# construct file
	
	var out := PackedStringArray()

	out.append("{")
	out.append('  "v": "0.2",')
	out.append('  "name": "%s",' % _escape_json_string(bp_name))
	out.append('  "smoothAngle": %d,' % smooth_angle)
	out.append('  "gridSize": %d,' % grid_size)
	out.append('  "format": "%s",' % bp_format)
	out.append('  "mesh": {')
	out.append('    "majorVersion": %d,' % mesh_major)
	out.append('    "minorVersion": %d,' % mesh_minor)

	# Vertices
	out.append('    "vertices": [')
	_append_float_array(out, vertex_array, "      ")
	out.append("    ],")

	# Edges
	out.append('    "edges": [')
	_append_int_array(out, edges, "      ")
	out.append("    ],")

	# Edge flags
	out.append('    "edgeFlags": [')
	_append_int_array(out, edge_flags, "      ")
	out.append("    ],")

	# Faces
	out.append('    "faces": [')

	for i in range(md.faces.size()):
		var face := md.faces[i]

		# Resolve face attributes
		var t_arr: Array
		var tm_val: int
		var te_val: int

		if i < face_extras.size() and not face_extras[i].is_empty():
			var extras: Dictionary = face_extras[i]
			t_arr = extras.get("t", _default_t(face.size()))
			tm_val = int(extras.get("tm", _default_tm(face.size())))
			te_val = int(extras.get("te", 0))
		else:
			t_arr = _default_t(face.size())
			tm_val = _default_tm(face.size())
			te_val = 0

		# Build face block
		out.append("      {")
		
		# Reverse order for obj -> blueprint
		var face_verts: PackedInt32Array
		if not is_round_trip:
			face_verts = PackedInt32Array()
			for j in range(face.size() - 1, -1, -1):
				face_verts.append(face[j])
		else:
			face_verts = face

		var v_parts := PackedStringArray()
		for idx in face_verts:
			v_parts.append(str(int(idx)))
		out.append('        "v": [%s],' % ", ".join(v_parts))

		# "t": [...]
		var t_parts := PackedStringArray()
		for t in t_arr:
			t_parts.append(str(int(t)))
		out.append('        "t": [%s],' % ", ".join(t_parts))

		# "tm": N,
		out.append('        "tm": %d,' % tm_val)

		# "te": N
		out.append('        "te": %d' % te_val)

		# Close face dict
		if i < md.faces.size() - 1:
			out.append("      },")
		else:
			out.append("      }")

	out.append("    ]")
	out.append("  },")

	# --- Rivets ---
	out.append('  "rivets": {')
	out.append('    "profiles": [')

	if rivets_profiles.is_empty():
		# Default profile
		out.append("      {")
		out.append('        "model": 0,')
		out.append('        "spacing": 0.1,')
		out.append('        "diameter": 0.05,')
		out.append('        "height": 0.025,')
		out.append('        "padding": 0.04')
		out.append("      }")
	else:
		for pi in range(rivets_profiles.size()):
			var prof: Dictionary = rivets_profiles[pi]
			out.append("      {")
			out.append('        "model": %d,' % int(prof.get("model", 0)))
			out.append('        "spacing": %s,' % _format_rivet_float(prof.get("spacing", 0.1)))
			out.append('        "diameter": %s,' % _format_rivet_float(prof.get("diameter", 0.05)))
			out.append('        "height": %s,' % _format_rivet_float(prof.get("height", 0.025)))
			out.append('        "padding": %s' % _format_rivet_float(prof.get("padding", 0.04)))
			if pi < rivets_profiles.size() - 1:
				out.append("      },")
			else:
				out.append("      }")

	out.append("    ],")

	# Rivet nodes
	if rivets_nodes.is_empty():
		out.append('    "nodes": []')
	else:
		out.append('    "nodes": %s' % JSON.stringify(rivets_nodes))

	out.append("  }")
	out.append("}")

	return "\n".join(out) + "\n"


# ======================== #
# Float array formatting   #
# ======================== #
static func _append_float_array(out: PackedStringArray, arr: Array, indent: String) -> void:
	for i in range(arr.size()):
		var formatted := "%.6f" % float(arr[i])
		if i < arr.size() - 1:
			out.append("%s%s," % [indent, formatted])
		else:
			out.append("%s%s" % [indent, formatted])


## Writes integer values one-per-line.
static func _append_int_array(out: PackedStringArray, arr: Array, indent: String) -> void:
	for i in range(arr.size()):
		if i < arr.size() - 1:
			out.append("%s%d," % [indent, int(arr[i])])
		else:
			out.append("%s%d" % [indent, int(arr[i])])


# ======================== #
# Edge generation          #
# ======================== #
static func _build_edges_from_faces(faces: Array[PackedInt32Array]) -> Array:
	var edge_set := {}
	var edges: Array = []
	var flags: Array = []

	for face in faces:
		var n := face.size()
		for i in range(n):
			var v1 := face[i]
			var v2 := face[(i + 1) % n]

			var key_a := v1
			var key_b := v2
			if v1 > v2:
				key_a = v2
				key_b = v1

			var key := "%d_%d" % [key_a, key_b]

			if not edge_set.has(key):
				edge_set[key] = true
				edges.append(key_a)
				edges.append(key_b)
				flags.append(0)

	return [edges, flags]


# ======================== #
# Default face attributes  #
# ======================== #
static func _default_t(n: int) -> Array:
	var t: Array = []
	for i in range(n):
		t.append(5)
	return t


## Tri = 65793, Quad = 16843009
static func _default_tm(n: int) -> int:
	if n == 3:
		return 65793
	return 16843009


# ======================== #
# Helpers                  #
# ======================== #
static func _escape_json_string(s: String) -> String:
	s = s.replace("\\", "\\\\")
	s = s.replace('"', '\\"')
	s = s.replace("\n", "\\n")
	s = s.replace("\r", "\\r")
	s = s.replace("\t", "\\t")
	return s


## Format rivets
static func _format_rivet_float(value: float) -> String:
	var s := "%.6f" % value
	# Trim trailing zeros
	if "." in s:
		s = s.rstrip("0")
		if s.ends_with("."):
			s += "0"
	return s

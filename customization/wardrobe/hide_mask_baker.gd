@tool
class_name HideMaskBaker
extends RefCounted
## Bakes what an [OutfitItem] covers into a black/white mask over the UVs of
## the surface beneath it: the body's skin, or a garment on a lower
## [member OutfitItem.layer] (e.g. a swimsuit under a shirt).
##
## For every texel of the surface beneath, a short ray is cast along its
## normal, from [member OutfitItem.hide_depth] inside to
## [member OutfitItem.hide_distance] outside it. If it hits the garment, the
## texel is hidden (white). Loose parts (a flared skirt over the hips) are
## further away than the ray reaches, so what's under them stays visible;
## tight parts (a waistband) and anything that pokes through are hidden.
##
## All scenes are read in their bind pose, with the covering item's
## [member OutfitItem.shape_key_overrides] applied to matching shape keys.

const _HIDDEN := 255
## Texels of empty UV space next to an island that copy its value, so
## filtering at island edges never reads an unbaked texel.
const _PADDING_PIXELS := 2


## Returns [param item]'s body hide mask as an L8 image, white where skin is
## hidden.
static func bake(item: OutfitItem) -> Image:
	var body_settings := item.hide_mask_body
	return _bake(item, body_settings.scene, body_settings.skin_material, body_settings.resolution)


## Returns the mask of what [param item] covers of [param under], over
## [param under]'s UVs, as an L8 image.
static func bake_over(item: OutfitItem, under: OutfitItem) -> Image:
	return _bake(item, under.scene, null, item.hide_mask_body.resolution)


## Saves [param image] as a PNG at [param path]. In the editor, also imports
## it and returns the texture; elsewhere returns null.
static func save_mask(image: Image, path: String) -> Texture2D:
	var error := image.save_png(path)
	if error != OK:
		push_error("Couldn't save hide mask to '%s': %s" % [path, error_string(error)])
		return null
	print("Baked hide mask %s" % path)
	if not Engine.is_editor_hint():
		return null
	# Editor classes are looked up dynamically: they don't exist in exported games.
	var file_system: Object = Engine.get_singleton(&"EditorInterface").get_resource_filesystem()
	file_system.update_file(path)
	file_system.reimport_files(PackedStringArray([path]))
	return load(path)


## Masks the parts of [param target_scene] (only surfaces using
## [param target_material], if given) that [param item] covers.
static func _bake(
		item: OutfitItem, target_scene: PackedScene, target_material: Material, size: int
) -> Image:
	var target: Node = target_scene.instantiate()
	var garment: Node = item.scene.instantiate()
	var shape_weights := item.shape_key_overrides
	var garment_triangles := _collect_triangles(garment, null, shape_weights)
	var target_triangles := _collect_triangles(target, target_material, shape_weights)
	target.free()
	garment.free()

	var hidden := PackedByteArray()
	hidden.resize(size * size)
	var covered := PackedByteArray()
	covered.resize(size * size)
	if garment_triangles.positions.is_empty() or target_triangles.positions.is_empty():
		push_warning("Hide mask for '%s' is empty: no geometry found." % item.id)
		return Image.create_from_data(size, size, false, Image.FORMAT_L8, hidden)

	var reach := maxf(item.hide_distance, item.hide_depth)
	var grid := _TriangleGrid.new(garment_triangles.positions, maxf(reach * 2.0, 0.005), reach)
	var garment_bounds := grid.bounds.grow(reach)
	var ray := Vector2(item.hide_depth, item.hide_distance)
	var positions := target_triangles.positions
	var normals := target_triangles.normals
	var uvs := target_triangles.uvs
	for i in range(0, positions.size(), 3):
		if not _triangle_bounds(positions, i).intersects(garment_bounds):
			continue
		_rasterize_triangle(i, positions, normals, uvs, size, grid, ray, hidden, covered)

	_pad_islands(hidden, covered, size)
	return Image.create_from_data(size, size, false, Image.FORMAT_L8, hidden)


## Rasterizes triangle [param i] into the mask. [param ray] is how far each
## texel's ray reaches (inside, outside) along the surface normal.
static func _rasterize_triangle(
		i: int,
		positions: PackedVector3Array,
		normals: PackedVector3Array,
		uvs: PackedVector2Array,
		size: int,
		grid: _TriangleGrid,
		ray: Vector2,
		hidden: PackedByteArray,
		covered: PackedByteArray,
) -> void:
	var a := uvs[i] * size
	var b := uvs[i + 1] * size
	var c := uvs[i + 2] * size
	var area := (b - a).cross(c - a)
	if absf(area) < 1e-8:
		return

	var min_x := clampi(floori(minf(a.x, minf(b.x, c.x))), 0, size - 1)
	var max_x := clampi(ceili(maxf(a.x, maxf(b.x, c.x))), 0, size - 1)
	var min_y := clampi(floori(minf(a.y, minf(b.y, c.y))), 0, size - 1)
	var max_y := clampi(ceili(maxf(a.y, maxf(b.y, c.y))), 0, size - 1)
	# Accept texels whose centre is up to half a pixel outside, so seams leave
	# no gaps. Weight / tolerance = signed pixel distance to the opposite edge.
	var edge_lengths := Vector3(b.distance_to(c), c.distance_to(a), a.distance_to(b))
	var tolerance := edge_lengths * (-0.5 / absf(area))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var w0 := (b - p).cross(c - p) / area
			var w1 := (c - p).cross(a - p) / area
			var w2 := 1.0 - w0 - w1
			if w0 < tolerance.x or w1 < tolerance.y or w2 < tolerance.z:
				continue
			var index := y * size + x
			covered[index] = 1
			if hidden[index] == _HIDDEN:
				continue
			var point := positions[i] * w0 + positions[i + 1] * w1 + positions[i + 2] * w2
			var normal := (normals[i] * w0 + normals[i + 1] * w1 + normals[i + 2] * w2).normalized()
			var inside := point - normal * ray.x
			var outside := point + normal * ray.y
			if grid.segment_hits(inside, outside):
				hidden[index] = _HIDDEN


static func _pad_islands(hidden: PackedByteArray, covered: PackedByteArray, size: int) -> void:
	for pass_index in _PADDING_PIXELS:
		var newly_covered := PackedInt32Array()
		for y in size:
			for x in size:
				var index := y * size + x
				if covered[index]:
					continue
				for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var nx := x + offset.x
					var ny := y + offset.y
					if nx < 0 or ny < 0 or nx >= size or ny >= size:
						continue
					var neighbor := ny * size + nx
					if covered[neighbor]:
						hidden[index] = maxi(hidden[index], hidden[neighbor])
						newly_covered.append(index)
		for index in newly_covered:
			covered[index] = 1


## Triangle soup (3 entries per triangle) of every mesh under [param root],
## or only of surfaces using [param material] when one is given.
static func _collect_triangles(
		root: Node,
		material: Material,
		shape_weights: Dictionary[StringName, float],
) -> _Triangles:
	var triangles := _Triangles.new()
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for mesh_instance: MeshInstance3D in meshes:
		var mesh := mesh_instance.mesh as ArrayMesh
		if mesh == null:
			continue
		var to_root := _transform_to(mesh_instance, root)
		for surface in mesh.get_surface_count():
			if material and mesh_instance.get_active_material(surface) != material:
				continue
			_append_surface(triangles, mesh, surface, to_root, shape_weights)
	return triangles


static func _append_surface(
		triangles: _Triangles,
		mesh: ArrayMesh,
		surface: int,
		to_root: Transform3D,
		shape_weights: Dictionary[StringName, float],
) -> void:
	if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
		return
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var shapes := mesh.surface_get_blend_shape_arrays(surface)
	var relative := mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE
	var base := vertices.duplicate()
	for shape in mesh.get_blend_shape_count():
		var weight: float = shape_weights.get(mesh.get_blend_shape_name(shape), 0.0)
		if is_zero_approx(weight):
			continue
		var shape_vertices: PackedVector3Array = shapes[shape][Mesh.ARRAY_VERTEX]
		for v in vertices.size():
			var offset := shape_vertices[v] if relative else shape_vertices[v] - base[v]
			vertices[v] += offset * weight

	if indices.is_empty():
		indices.resize(vertices.size())
		for v in vertices.size():
			indices[v] = v
	var normal_basis := to_root.basis.inverse().transposed()
	for index in indices:
		var normal := normals[index] if not normals.is_empty() else Vector3.UP
		triangles.positions.append(to_root * vertices[index])
		triangles.normals.append((normal_basis * normal).normalized())
		triangles.uvs.append(uvs[index] if not uvs.is_empty() else Vector2.ZERO)


static func _triangle_bounds(positions: PackedVector3Array, i: int) -> AABB:
	return AABB(positions[i], Vector3.ZERO).expand(positions[i + 1]).expand(positions[i + 2])


## Works outside the scene tree, unlike [member Node3D.global_transform].
static func _transform_to(node: Node, root: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current := node
	while current != root and current != null:
		if current is Node3D:
			result = current.transform * result
		current = current.get_parent()
	return result


class _Triangles:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()


## Uniform grid over triangles for short segment queries. Each triangle is
## stored in every cell its bounds (grown by the query reach) touch, so a
## segment only needs the cell holding its midpoint.
class _TriangleGrid:
	var bounds: AABB
	var _positions: PackedVector3Array
	var _cell_size: float
	var _cells: Dictionary[Vector3i, PackedInt32Array] = {}

	func _init(positions: PackedVector3Array, cell_size: float, reach: float) -> void:
		_positions = positions
		_cell_size = cell_size
		bounds = AABB(positions[0], Vector3.ZERO)
		for i in range(0, positions.size(), 3):
			var triangle_bounds := HideMaskBaker._triangle_bounds(positions, i)
			bounds = bounds.merge(triangle_bounds)
			triangle_bounds = triangle_bounds.grow(reach)
			var from := _cell_of(triangle_bounds.position)
			var to := _cell_of(triangle_bounds.end)
			for x in range(from.x, to.x + 1):
				for y in range(from.y, to.y + 1):
					for z in range(from.z, to.z + 1):
						var key := Vector3i(x, y, z)
						var cell: PackedInt32Array = _cells.get(key, PackedInt32Array())
						cell.append(i)
						_cells[key] = cell

	func segment_hits(from: Vector3, to: Vector3) -> bool:
		var key := _cell_of((from + to) * 0.5)
		if not _cells.has(key):
			return false
		var direction := to - from
		for i in _cells[key]:
			var a := _positions[i]
			var b := _positions[i + 1]
			var c := _positions[i + 2]
			if _segment_hits_triangle(from, direction, a, b, c):
				return true
		return false

	func _cell_of(point: Vector3) -> Vector3i:
		return Vector3i((point / _cell_size).floor())

	## Möller–Trumbore, two-sided, for the segment from + direction * [0, 1].
	static func _segment_hits_triangle(
			from: Vector3, direction: Vector3, a: Vector3, b: Vector3, c: Vector3
	) -> bool:
		var edge1 := b - a
		var edge2 := c - a
		var p := direction.cross(edge2)
		var determinant := edge1.dot(p)
		if absf(determinant) < 1e-12:
			return false
		var inverse := 1.0 / determinant
		var s := from - a
		var u := s.dot(p) * inverse
		if u < 0.0 or u > 1.0:
			return false
		var q := s.cross(edge1)
		var v := direction.dot(q) * inverse
		if v < 0.0 or u + v > 1.0:
			return false
		var t := edge2.dot(q) * inverse
		return t >= 0.0 and t <= 1.0

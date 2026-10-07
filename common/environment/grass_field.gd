@tool
class_name GrassField
extends Node3D
## Scatters short grass blades over a square area made of chunks.
##
## Each chunk is a [MultiMeshInstance3D], so the engine culls chunks outside
## the view and fades distant ones out (see [member fade_distance]). Chunks
## draw one of a few pre-generated blade layouts, picked per world cell, so the
## pattern never visibly repeats. With [member endless], the field recenters
## on [member target] in whole-chunk steps as it moves, so the grass never
## ends; every cell keeps its layout, so the shift is invisible.
##
## Blades are generated from [member random_seed], so the field looks the same
## every run, and are rebuilt whenever a setting changes, in the editor too.
## The chunks are internal nodes and aren't saved into the scene. Blades bend
## away from [member target]; see grass.gdshader for wind and color settings.

## Width and depth of the grass around the target (or this node), in meters.
@export_range(8.0, 500.0, 1.0, "suffix:m") var size := 72.0:
	set(value):
		size = value
		_queue_rebuild()
## Blades per square meter.
@export_range(1.0, 400.0, 1.0) var density := 140.0:
	set(value):
		density = value
		_queue_rebuild()
@export_range(0.02, 2.0, 0.01, "suffix:m") var min_height := 0.08:
	set(value):
		min_height = value
		_queue_rebuild()
@export_range(0.02, 2.0, 0.01, "suffix:m") var max_height := 0.16:
	set(value):
		max_height = value
		_queue_rebuild()
@export_range(0.005, 0.2, 0.001, "suffix:m") var blade_width := 0.022:
	set(value):
		blade_width = value
		_queue_rebuild()
@export var random_seed := 1:
	set(value):
		random_seed = value
		_queue_rebuild()
## Material for the blades; should use grass.gdshader.
@export var material: ShaderMaterial:
	set(value):
		material = value
		_queue_rebuild()
## Chunks beyond this distance from the camera fade out.
@export_range(5.0, 500.0, 1.0, "suffix:m") var fade_distance := 32.0:
	set(value):
		fade_distance = value
		_queue_rebuild()
## Blades bend away from this node, and an [member endless] field follows it.
@export var target: Node3D
## Keep the field centered on [member target] while playing.
@export var endless := true

const CHUNK_SIZE := 8.0
const LAYOUT_COUNT := 4
const BLADE_SEGMENTS := 3
## Random tints (multiplied with the shader's colors) for variety.
const VARIATION := [
	Color(1.0, 1.0, 1.0), Color(0.92, 1.0, 0.85), Color(1.06, 1.02, 0.86), Color(0.85, 0.95, 0.88),
]

var _layouts: Array[MultiMesh] = []
var _chunks: Array[MultiMeshInstance3D] = []
var _chunks_per_side := 0
var _center_cell := Vector2i(1 << 30, 1 << 30)
var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	if target == null:
		return
	if material:
		material.set_shader_parameter(&"bend_center", target.global_position)
	if endless and not Engine.is_editor_hint():
		var position_2d := Vector2(target.global_position.x, target.global_position.z)
		var cell := Vector2i((position_2d / CHUNK_SIZE).floor())
		if cell != _center_cell:
			_recenter(cell)


func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for chunk in _chunks:
		chunk.free()
	_chunks.clear()
	_layouts.clear()
	if material == null:
		return

	var blade := _make_blade_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var blades_per_chunk := roundi(CHUNK_SIZE * CHUNK_SIZE * density)
	for i in LAYOUT_COUNT:
		_layouts.append(_make_layout(blade, rng, blades_per_chunk))

	_chunks_per_side = maxi(1, ceili(size / CHUNK_SIZE))
	for i in _chunks_per_side * _chunks_per_side:
		var chunk := MultiMeshInstance3D.new()
		chunk.material_override = material
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.visibility_range_end = fade_distance
		chunk.visibility_range_end_margin = fade_distance * 0.25
		chunk.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# Blades sway outside their rest bounds.
		chunk.extra_cull_margin = 0.5
		add_child(chunk)
		_chunks.append(chunk)
	_recenter(Vector2i.ZERO)


## Places the chunks on the cells around [param cell], each showing the layout
## that belongs to its world cell.
func _recenter(cell: Vector2i) -> void:
	_center_cell = cell
	var first := cell - Vector2i.ONE * floori(_chunks_per_side / 2.0)
	for i in _chunks.size():
		var world_cell := first + Vector2i(i % _chunks_per_side, floori(float(i) / _chunks_per_side))
		var chunk := _chunks[i]
		chunk.multimesh = _layouts[absi(hash(world_cell)) % LAYOUT_COUNT]
		chunk.global_position = Vector3(
				(world_cell.x + 0.5) * CHUNK_SIZE, global_position.y, (world_cell.y + 0.5) * CHUNK_SIZE
		)


func _make_layout(blade: Mesh, rng: RandomNumberGenerator, count: int) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = blade
	multimesh.instance_count = count
	for i in count:
		var blade_position := Vector3(rng.randf() - 0.5, 0.0, rng.randf() - 0.5) * CHUNK_SIZE
		var height := rng.randf_range(min_height, max_height)
		var width := rng.randf_range(0.8, 1.2)
		var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		var scale_basis := Basis.from_scale(Vector3(width, height, width))
		var blade_basis := Basis(Vector3.UP, rng.randf() * TAU) * lean * scale_basis
		multimesh.set_instance_transform(i, Transform3D(blade_basis, blade_position))
		var tint: Color = VARIATION[rng.randi() % VARIATION.size()]
		multimesh.set_instance_color(i, tint * rng.randf_range(0.9, 1.08))
		multimesh.set_instance_custom_data(i, Color(rng.randf(), 0.0, 0.0, 0.0))
	return multimesh


## A tapered, slightly curved blade one unit tall; UV.y runs root (0) to tip (1).
## Instances scale only its height (and its width by ~1), so the width is in
## meters and the forward curve is sized to the average blade height.
func _make_blade_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var tip_curve := (min_height + max_height) * 0.5 * 0.35
	for level in BLADE_SEGMENTS:
		var t := float(level) / BLADE_SEGMENTS
		var half_width := blade_width * 0.5 * (1.0 - t * 0.85)
		var curve := t * t * tip_curve
		vertices.append(Vector3(-half_width, t, curve))
		vertices.append(Vector3(half_width, t, curve))
		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))
	vertices.append(Vector3(0.0, 1.0, tip_curve))
	uvs.append(Vector2(0.5, 1.0))
	for i in vertices.size():
		normals.append(Vector3.UP)
	for level in BLADE_SEGMENTS - 1:
		var a := level * 2
		indices.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var last := (BLADE_SEGMENTS - 1) * 2
	indices.append_array([last, vertices.size() - 1, last + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

@tool
extends EditorScenePostImport
## Post-import script for set pieces (rooms, props).
##
## Assign it in a scene's Import dock (Import Script > Path).
## - Every material samples its textures with nearest filtering, so pixel-art
##   textures stay crisp instead of being blurred.
## - Generated trimesh collision is made two-sided, so thin walls and floors
##   block the player no matter which way their faces point.


func _post_import(scene: Node) -> Object:
	_use_nearest_filtering(scene)
	_make_collision_two_sided(scene)
	return scene


func _use_nearest_filtering(scene: Node) -> void:
	var materials: Dictionary[BaseMaterial3D, bool] = {}
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if material:
				materials[material] = true
	for material: BaseMaterial3D in materials:
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS


func _make_collision_two_sided(scene: Node) -> void:
	for collision: CollisionShape3D in scene.find_children("*", "CollisionShape3D", true, false):
		if collision.shape is ConcavePolygonShape3D:
			collision.shape.backface_collision = true

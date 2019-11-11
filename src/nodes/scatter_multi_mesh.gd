tool
extends ScatterBase

# --
# ScatterMultiMesh
# --
# Create a new multimesh for each child ScatterItem nodes. This node
# only looks for the meshes in a given scene and create new multimesh
# instances to render them. It ignores all the other nodes and scripts
# attached. 
# This is useful for grass, but not to place dozen of random NPCs for
# example.
# --
#
# --

class_name ScatterMultiMesh

## -- 
## Exported variables
## --

## --
## Internal variables
## --

## --
## Public methods
## --

# Called from any children when their exported parameters changes
func update():
	if not _is_ready():
		return
	_discover_items_info()
	_setup_distribution()
	_fill_area()

## --
## Internal methods
## --

func _ready():
	self.connect("curve_updated", self, "_on_curve_update")
	update()

func _on_curve_update():
	update()

func _fill_area():
	var count
	for i in _items:
		count = int(float(i.proportion) / _total_proportion * amount)
		_populate_multi_mesh(i, count)

func _populate_multi_mesh(item, amount):
	var result = _setup_multi_mesh(item, amount)
	var mm = result[0]
	var src_node = result[1]
	var exclusion_areas = item.get_exclusion_areas()
	
	for i in range(0, amount):
		var coords = _get_next_valid_pos(exclusion_areas)
		var t = Transform()
		
		# Update item scaling
		var s = Vector3.ONE + abs(_distribution.get_float()) * scale_randomness
		if item.ignore_initial_scale:
			t = t.scaled(s * global_scale * item.scale_modifier)
		else:
			t = t.scaled(s * global_scale * item.scale_modifier * src_node.scale)
		
		# Update item rotation
		var rotation = _distribution.get_vector3() * rotation_randomness
		if item.ignore_initial_rotation:
			t = t.rotated(Vector3.RIGHT, rotation.x)
			t = t.rotated(Vector3.UP, rotation.y)
			t = t.rotated(Vector3.BACK, rotation.z)
		else:
			t = t.rotated(Vector3.RIGHT, rotation.x + src_node.rotation.x)
			t = t.rotated(Vector3.UP, rotation.y + src_node.rotation.y)
			t = t.rotated(Vector3.BACK, rotation.z + src_node.rotation.z)
		
		# Update item location
		var pos_y = 0.0
		if project_on_floor:
			pos_y = _get_ground_position(coords)
		t.origin = get_global_transform().origin + Vector3(coords.x, pos_y, coords.z)
		if not item.ignore_initial_position:
			t.origin += src_node.translation
		mm.multimesh.set_instance_transform(i, t)
	
func _setup_multi_mesh(item, count):
	var instance = item.get_node("MultiMeshInstance")
	if not instance:
		instance = MultiMeshInstance.new()
		instance.set_name("MultiMeshInstance")
		item.add_child(instance)
		instance.set_owner(get_tree().get_edited_scene_root())
	if not instance.multimesh:
		instance.multimesh = MultiMesh.new()
	
	var mesh_instance = _get_mesh_from_scene(item.item_path)
	instance.material_override = mesh_instance.get_surface_material(0)
	instance.multimesh.instance_count = 0 # Set this to zero or you can't change the other values
	instance.multimesh.mesh = mesh_instance.mesh
	instance.multimesh.transform_format = 1
	instance.multimesh.instance_count = count

	return [instance, mesh_instance]

func _get_mesh_from_scene(node_path):
	var target = load(node_path).instance()
	for c in target.get_children():
		if c is MeshInstance:
			return c
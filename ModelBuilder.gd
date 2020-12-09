extends Node

# Just the skeleton I can access anywhere, mostly for debug purposes
var cheat_skeleton := Skeleton.new()

func build(source_file, options):
	var file = File.new()
	if file.open(source_file, File.READ) != OK:
		print("Failed to open %s" % source_file)
		return FAILED
		
	print("Opened %s" % source_file)
	
	var path = "%s/Models" % self.get_script().get_path().get_base_dir()
	var abc_file = load("%s/ABC.gd" % path)
	var abc6_file = load("%s/ABC6.gd" % path)
	
	# Our helper script
	var abc_helper_script = load("%s/ABCHelper.gd" % self.get_script().get_path().get_base_dir())
	
	var model = abc_file.ABC.new()
	
	var response = model.read(file)
	if response.code == model.IMPORT_RETURN.ERROR:
		print("Checking ABC version 6 reader!")
		# Try ABC 6
		model = abc6_file.ABC.new()
		response = model.read(file)
		
		#...nope, we're ded.
		if response.code == model.IMPORT_RETURN.ERROR:
			file.close()
			print("IMPORT ERROR: %s" % response.message)
			return FAILED
		
		
	# Actually close the darn thing
	file.close()
		
	# Setup our new scene
	var scene = PackedScene.new()
	
	# Create our nodes
	var root = Spatial.new()
	
	# Setup the nodes
	root.name = "Root"
	
	root.set_script(abc_helper_script)
	
	var skeleton = Skeleton.new()
	skeleton.name = "Skeleton"
	skeleton = build_skeleton(model, skeleton)
	root.add_child(skeleton)
	skeleton.owner = root
	self.cheat_skeleton = skeleton
	
	var meshes = fill_array_mesh(model)

	# Loop through our pieces, and add them to mesh instances
	for i in range(len(meshes)):
	#for mesh in meshes:
		var mesh = meshes[i]
		var piece = model.pieces[i]
		var mesh_instance = MeshInstance.new()
		mesh_instance.name = piece.name
		mesh_instance.mesh = mesh
		skeleton.add_child(mesh_instance)
		mesh_instance.owner = root
	# End For
	
	# Animation time!
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimPlayer"
	root.add_child(anim_player)
	anim_player.owner = root
	anim_player = process_animations(model, anim_player)
	
	# Pack our scene!
	scene.pack(root)
	
	return scene

func fill_array_mesh(model):
	var meshes = []
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for piece in model.pieces:
		var verts = PoolVector3Array()
		var uvs = PoolVector2Array()
		var normals = PoolVector3Array()
		var indices = PoolIntArray()
		
		# Holds vertex_bone_data
		# Basically the weights per a vertex
		var piece_bone_data = []
		
		# Count
		var vert_weight_count = PoolIntArray()
		
		for lod in piece.lods:
			for vertex in lod.vertices:
				verts.append(vertex.location)
				normals.append(vertex.normal)
				vert_weight_count.append(vertex.weight_count)
				var vertex_bone_data = []
				for weight in vertex.weights:
					vertex_bone_data.append([weight.node_index, weight.bias])
				# End For
				piece_bone_data.append(vertex_bone_data)
			# End For
			for face in lod.faces:
				for vertex in face.vertices:
					var texcoord = vertex.texcoord
					var vertex_index = vertex.vertex_index
					
					uvs.append( Vector2( texcoord.x, texcoord.y ) )
					indices.append(vertex_index)
				# End For
			# End For
			# Only want the first LOD
			break
		# End For
		
		# If we need to flip the indices, then do so
		# This applies to pretty much every model except for Shogo, and Blood 2...
		if !model.front_to_back_indices:
			indices.invert()
			uvs.invert()
			
		var i = 0
		for index in indices:
			st.add_uv(uvs[i])
			st.add_normal(normals[index])
			
			var this_vert_bones = PoolIntArray()
			var this_vert_weights = PoolRealArray()
			
			# Index 0: Node Index
			# Index 1: Bias
			for bone_data in piece_bone_data[index]:
				this_vert_bones.append(bone_data[0])
				this_vert_weights.append(bone_data[1])
			# End For
			# For some reason these MUST be 4 values each!
			var remainder = 4 - vert_weight_count[index]
			for filler in range(remainder):
				this_vert_bones.append(-1)
				this_vert_weights.append(0.0)
			# End For
				
			st.add_bones(this_vert_bones)
			st.add_weights(this_vert_weights)
			
			st.add_vertex(verts[index])
			i += 1
		
		meshes.append(st.commit())
		
		# Clear out the previous piece
		st.clear()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)


	return meshes
# End Func

func build_skeleton(model, skeleton : Skeleton):
	for i in range(model.node_count):
		var lt_node = model.nodes[i]
		var bind_matrix = lt_node.bind_matrix
		#print("Node %s\n - Index: %d\n - Flags: %d\n - Bind Matrix: ( (%f/%f/%f), (%f/%f/%f), (%f/%f/%f), (%f/%f/%f) )\n - Child Count: %d" % [lt_node.name, lt_node.index, lt_node.flags, lt_node.bind_matrix[0].x, lt_node.bind_matrix[0].y, lt_node.bind_matrix[0].z, lt_node.bind_matrix[1].x, lt_node.bind_matrix[1].y, lt_node.bind_matrix[1].z, lt_node.bind_matrix[2].x, lt_node.bind_matrix[2].y, lt_node.bind_matrix[2].z, lt_node.bind_matrix[3].x, lt_node.bind_matrix[3].y, lt_node.bind_matrix[3].z, lt_node.child_count])
		skeleton.add_bone(lt_node.name)

		if lt_node.parent != null:
			skeleton.set_bone_parent(i, lt_node.parent.index)
			bind_matrix = lt_node.parent.bind_matrix.inverse() * bind_matrix
		
		skeleton.set_bone_rest(i, bind_matrix)
	# End For
		
	return skeleton
# End Func


func process_animations(model, anim_player : AnimationPlayer):
	
	for lt_anim in model.animations:
		var anim = Animation.new()
		# Pre-make our track ids
		for ni in range(model.node_count):
			var key = "Skeleton:%s" % model.nodes[ni].name
			var track_id = anim.add_track(Animation.TYPE_TRANSFORM)
			anim.track_set_path(track_id, key)
		# End For
		
		var last_scaled_key = 0
		for kfi in range(lt_anim.keyframe_count):
			var lt_keyframe = lt_anim.keyframes[kfi]
			var scaled_key = lt_keyframe.time
			if scaled_key != 0:
				scaled_key /= 1000.0
			# End If
			self.recursively_apply_transform(model, 0, kfi, lt_anim, anim, scaled_key, Transform.IDENTITY)
			last_scaled_key = scaled_key

			# Check for command string...
			if lt_keyframe.command_string != "":
				var key = "." # Root
				var track_id = anim.add_track(Animation.TYPE_METHOD)
				anim.track_set_path(track_id, key)
				anim.track_insert_key(track_id, scaled_key, {"method": "run_command_string", "args": [ lt_keyframe.command_string ]})
			# End If	

		# End For
		
		anim.length = last_scaled_key
		anim_player.add_animation(lt_anim.name, anim)
	# End For
	
	return anim_player
# End Func


# This is quite a function!
# Call this within a keyframe loop
func recursively_apply_transform(model, node_index, keyframe_index, lt_anim, godot_anim : Animation, scaled_key, parent_matrix):
	var node = model.nodes[node_index]
	
	var transform = lt_anim.node_keyframes[node_index][keyframe_index]
	var matrix = self.lt_transform_to_godot_transform(transform.location, transform.rotation)
	var matrix_copy = matrix
	
	# This is the thing that's broken for version 9-13 animations!
	if model.version > 6:
		matrix = parent_matrix * matrix 
		matrix_copy = matrix
		#matrix = node.inverse_bind_matrix * matrix
		matrix = cheat_skeleton.get_bone_rest(node_index).inverse() * matrix
		#matrix *= node.bind_matrix
		#matrix = parent_matrix * matrix 

	var translation = matrix.origin 
	var rotation  = matrix.basis.get_rotation_quat()
	
	# Needed for v6!
	if model.flip_anim:
		rotation = rotation.inverse()
	
	# Node index SHOULD equal track id!
	godot_anim.transform_track_insert_key(node_index, scaled_key, translation, rotation, Vector3(1.0, 1.0, 1.0))
	
	# Now recursively crawl through the child nodes
	for child_index in node.child_count:
		node_index += 1
		node_index = recursively_apply_transform(model, node_index, keyframe_index, lt_anim, godot_anim, scaled_key, matrix_copy)
	# End For
	
	return node_index
# End Func

func lt_transform_to_godot_transform(loc, rot):
	var transform = Transform()
	var basis = Basis(rot)
	transform.basis = basis
	transform.origin = loc
	return transform
	

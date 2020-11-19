class ABC:
	var name = ""

	const version_constant = "MonolithExport Model File v6"

	# Header
	var version = 0
	var node_count = 0
	var lod_count = 0
	var weight_set_count = 0
	var command_string = ""
	var internal_radius = 0
	var lod_distances = []

	# Piece
	var pieces = []
	
	# Node
	var nodes = []
	var weight_sets = []
	
	# Child Models
	var child_models = []
	
	# Animations
	var animations = []
	
	# AnimDims
	var anim_dims = []
	
	# Transform Info
	var front_to_back_indices = true
	var flip_anim = true

	func _init():
		pass
	# End Func
	
	enum IMPORT_RETURN{SUCCESS, ERROR}
	
	func read(f : File):
		var next_section_offset = 0
		while next_section_offset != -1:
			f.seek(next_section_offset)
			
			var section_name = self.read_string(f)
			next_section_offset = f.get_32()
			
			if section_name == 'Header':
				var version_text = self.read_string(f)
				print("ABC Version: %s" % version_text)
				
				if version_text != self.version_constant:
					return self._make_response(IMPORT_RETURN.ERROR, 'Unsupported file version (%d)' % version_text)
				# End If
					
				self.version = 6
				self.command_string = self.read_string(f)
			elif section_name == 'Geometry':
				# There's only one piece for abc6
				var piece = Piece.new()
				piece.read(self, f)
				self.pieces.append(piece)

			elif section_name == 'Nodes':
				
				# Node count is calculated..
				# Depth first ordered
				var children_left = 1
				while children_left != 0:
					self.node_count += 1
					children_left -= 1
					var node = LTNode.new()
					node.read(self, f)
					children_left += node.child_count
					self.nodes.append(node)
				# End While
				
				# Link up the nodes
				LTNode.link_children(self.nodes, 0, null)
			elif section_name == "Animation":
				var animation_count = f.get_32()
				for i in range(animation_count):
					var animation = LTAnim.new()
					animation.read(self, f)
					self.animations.append(animation)
				# End For
			elif section_name == "AnimDims":
				# Maybe this should be a loop...
				var anim_dims = LTAnimDims.new()
				anim_dims.read(self, f)
				self.anim_dims = anim_dims
			elif section_name == "TransformInfo":
				self.front_to_back_indices = f.get_32()
				self.flip_anim = f.get_32()
			else:
				break
			# End If
			
			print("Finished %s\n -> Next section at %d" % [section_name, next_section_offset])
			
		# End While
		
		print("Finished loading ABC")
		print("-------------------------")
		return self._make_response(IMPORT_RETURN.SUCCESS)
	# End Func
	
	#
	# Helpers
	# 
	func _make_response(code, message = ''):
		return { 'code': code, 'message': message }
	# End Func
	
	func read_string(file : File):
		var length = file.get_16()
		return file.get_buffer(length).get_string_from_ascii()
	# End Func
	
	func read_vector2(file : File):
		var vec2 = Vector2()
		vec2.x = file.get_float()
		vec2.y = file.get_float()
		return vec2
	# End Func
		
	func read_vector3(file : File):
		var vec3 = Vector3()
		vec3.x = file.get_float()
		vec3.y = file.get_float()
		vec3.z = file.get_float()
		return vec3
	# End Func
	
	func read_quat(file : File):
		var quat = Quat()
		
		quat.x = file.get_float()
		quat.y = file.get_float()
		quat.z = file.get_float()
		quat.w = file.get_float()
		return quat
		
	func read_matrix(file : File):
		var matrix_4x4 = []
		for i in range(16):
			matrix_4x4.append(file.get_float())
			
		return self.convert_4x4_to_transform(matrix_4x4)
	# End Func
	
	func convert_4x4_to_transform(matrix):
		return Transform(
			Vector3( matrix[0], matrix[4], matrix[8]  ),
			Vector3( matrix[1], matrix[5], matrix[9]  ),
			Vector3( matrix[2], matrix[6], matrix[10] ),
			Vector3( matrix[3], matrix[7], matrix[11] )
		)

	##################
	# Internal Classes
	##################
	class Piece:
		var name = ""
		
		var material_index = 0
		var specular_power = 0.0
		var specular_scale = 0.0
		var lod_weight = 0.0
		var padding = 0
		
		# With all LODS!
		var total_vert_count = 0
		var vertex_start_numbers = []
		var lods = []
		
		func read(abc : ABC, f : File):
			self.material_index = 0
			self.specular_power = 0
			self.specular_scale = 1

			self.name = "Piece"
			
			# Bounds for the geo?
			var bounds_min = abc.read_vector3(f)
			var bounds_max = abc.read_vector3(f)
			
			abc.lod_count = f.get_32()
			
			for _i in range(abc.lod_count +1):
				vertex_start_numbers.append(f.get_16())
			
			var pos = f.get_position()
			
			var face_count = f.get_32()
			var main_face_list = []
			
			# Main LOD faces are up front!
			for i in range(face_count):
				var face = abc.Face.new()
				face.read(abc, f)
				main_face_list.append(face)
				
			pos = f.get_position()
			self.total_vert_count = f.get_32()
			
			var main_vert_count = f.get_32()
			
			# For now we're only grabbing the main lod!
			# -----------------------------------------
			# For some reason LOD list contains the main lod too!
			#for i in range(abc.lod_count + 1):
			var lod = abc.LOD.new()
			lod.read(abc, f, main_face_list, face_count, main_vert_count)
			lods.append(lod)
			# End For
	# End Piece
		
	class LOD:
		var face_count = 0
		var vertex_count = 0
		
		var faces = []
		var vertices = []
		
		func read(abc : ABC, f : File, main_face_list : Array, face_count : int, main_vert_count : int):
			self.face_count = face_count
			self.vertex_count = main_vert_count
			
			# Copy over the face list
			self.faces = main_face_list.duplicate(true)

			for i in range(self.vertex_count):
				var vertex = abc.Vertex.new()
				vertex.read(abc, f)
				self.vertices.append(vertex)
			# End For
		# End Func
	# End LOD
		
	class Face:
		var vertices = []
		
		func read(abc : ABC, f : File):
			var texcoord = [ abc.read_vector2(f), abc.read_vector2(f), abc.read_vector2(f)]
			var vertex_index = [ f.get_16(), f.get_16(), f.get_16()]
			var face_normal = f.get_buffer(3)
			
			for i in range(3):
				var face_vertex = abc.FaceVertex.new()
				face_vertex.texcoord = texcoord[i]
				face_vertex.vertex_index = vertex_index[i]
				face_vertex.face_normal = face_normal[i]
				self.vertices.append(face_vertex)
			# End For
		# End Func
	# End Face
	
	class FaceVertex:
		# We have 3 UV's per face I guess!
		var texcoord = Vector2()
		var vertex_index = 0
		var face_normal = 0x0
		
		var reversed = false
		
		func read(abc : ABC, f : File):
			# This method is not used due to how the data is packed.
			# Please See Face.read!
			pass
		# End Func
	# End FaceVertex
	
	class Vertex:
		var sublod_vertex_index = 0xCDCD
		var vertex_replacements = [0, 0]
		var weight_count = 0
		var weights = []
		var location = Vector3()
		var normal = Vector3()
		
		func read(abc : ABC, f : File):
			self.location = abc.read_vector3(f)
			self.normal = Vector3(f.get_8(), f.get_8(), f.get_8())
			
			weight_count = 1
			var weight = abc.Weight.new()
			weight.read(abc, f)
			self.weights.append(weight)
			
			vertex_replacements = [ f.get_16(), f.get_16() ]
		# End Func
	# End Vertex
	
	class Weight:
		var node_index = 0
		var location = Vector3()
		var bias = 0.0
		
		func read(abc : ABC, f : File):
			self.node_index = f.get_8()
			self.bias = 1.0
		# End Func
	# End Weight

	# I miss namespaces...
	class LTNode:
		var name = ""
		var index = 0
		var flags = 0
		var bind_matrix = Transform()
		var inverse_bind_matrix = Transform()
		var child_count = 0
		
		# v6 specific
		var bounds_min = Vector3()
		var bounds_max = Vector3()
		var mesh_deformation_vertex_count = 0
		var mesh_deformation_vertex_list = []
		
		# Links
		var parent = null
		var children = []
		
		func read(abc : ABC, f : File):
			self.bounds_min = abc.read_vector3(f)
			self.bounds_max = abc.read_vector3(f)
			
			self.name = abc.read_string(f)
			self.index = f.get_16()
			self.flags = f.get_8()
			
			self.mesh_deformation_vertex_count = f.get_32()
			for i in range(self.mesh_deformation_vertex_count):
				self.mesh_deformation_vertex_list.append(f.get_16())
			# End If
			
			self.child_count = f.get_32()
			pass
		# End Func
		
		# Static for convience
		static func link_children(node_list, node_index, parent : LTNode):
			var node = node_list[node_index]
			
			if (parent != null):
				node.parent = parent
				parent.children.append(node)
			
			for _i in range(node.child_count):
				node_index += 1
				node_index = link_children(node_list, node_index, node)
			
			return node_index
		# End Func
	# End Node
	
	class WeightSet:
		var name = ""
		var node_count = 0
		var node_weights = []
		
		func read(abc : ABC, f : File):
			self.name = abc.read_string(f)
			self.node_count = f.get_32()
			for i in range(self.node_count):
				node_weights.append(f.get_float())
			# End For
		# End Func
	# End Weightset
	
	class LTTransform:
		var location = Vector3()
		var rotation = Quat()
		
		func read(abc : ABC, f : File):
			self.location = abc.read_vector3(f)
			self.rotation = abc.read_quat(f)
		# End Func
	# End LTTransform
	
	class LTAnim:
		var name = ""
		var extents = Vector3()
		var unknown = 0
		var interp_time = 200
		var keyframe_count = 0
		var keyframes = []
		var node_keyframes = []
		
		# v6 specific
		var bounds_min = Vector3()
		var bounds_max = Vector3()
		var animation_length = 0 #?
		var vertex_deformations = []
		var scale = Vector3()
		var transform = Vector3()
		
		func read(abc : ABC, f : File):
			var pos = f.get_position()
			self.name = abc.read_string(f)
			
			self.animation_length = f.get_32()
			self.bounds_min = abc.read_vector3(f)
			self.bounds_max = abc.read_vector3(f)
			
			# Not sure if this is correct!
			self.extents = self.bounds_max - self.bounds_min
			
			self.keyframe_count = f.get_32()
			
			for i in range (self.keyframe_count):
				var lt_keyframe = LTKeyframe.new()
				lt_keyframe.read(abc, f)
				self.keyframes.append(lt_keyframe)
			# End For
			
			for i in range(abc.node_count):
				var keyframes_per_node = []
				for j in range(self.keyframe_count):
					var lt_transform = LTTransform.new()
					lt_transform.read(abc, f)
					keyframes_per_node.append(lt_transform)
				# End For
				self.node_keyframes.append(keyframes_per_node)
				pos = f.get_position()
				
				var mesh_deformation_vertex_count = abc.nodes[i].mesh_deformation_vertex_count
				
				# If we have some vertex animations, handle it
				for j in range(self.keyframe_count * mesh_deformation_vertex_count):
					var location = Vector3( f.get_8(), f.get_8(), f.get_8() )
					self.vertex_deformations.append(location)
				# End For

				self.scale = abc.read_vector3(f)
				self.transform = abc.read_vector3(f)
				
				# Process the vertex animation
				for j in range(len(self.vertex_deformations)):
					var deformation = self.vertex_deformations[j]
					
					# To get the proper coordinates we must multiply our 0-255 vertex deformation by the scale value, 
					#then add the transform
					deformation = (deformation * scale) + transform
					
					self.vertex_deformations[j] = deformation
			# End For
			pos = f.get_position()
			var t = true
		# End Func
	# End LTAnim
	
	class LTKeyframe:
		var time = 0
		var command_string = ""
		
		# v6 specific
		var bounds_min = Vector3()
		var bounds_max = Vector3()
		
		func read(abc : ABC, f : File):
			self.time = f.get_32()
			self.bounds_min = abc.read_vector3(f)
			self.bounds_max = abc.read_vector3(f)
			self.command_string = abc.read_string(f)
			# End For
		# End Func
	# End LTKeyframe
	
	class LTAnimDims:
		var dims = []
		
		func read(abc : ABC, f : File):
			for i in range(len(abc.animations)):
				self.dims = abc.read_vector3(f)
			# End If
		# End Func
	# End LTAnimDims

using System;
using System.Collections;
using cgltf;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using GlitchyEngine.Renderer.Animation;
using GlitchyEngine.World;
using System.IO;

namespace GlitchyEngine.Content
{
	public static class ModelLoader
	{
		static readonly Matrix RightToLeftHand = .Scaling(1, 1, -1);

		public static Result<void> GetMeshNames(String filename, List<String> meshNames)
		{
			CGLTF.Options options = .();
			CGLTF.Data* data;
			CGLTF.Result result = CGLTF.ParseFile(options, filename, out data);

			if (!(result case .Success))
				return .Err;

			for (var mesh in data.Meshes)
			{
				meshNames.Add(new String(mesh.Name));
			}

			CGLTF.Free(data);

			return .Ok;
		}

		public static GeometryBinding LoadMesh(StringView fileName, StringView meshName, int primitiveIndex)
		{
			// TODO: add a context to remember which buffers were loaded before so that we don't load the same data multiple times.

			char8* scopedFileName = fileName.ToScopeCStr!();

			CGLTF.Options options = .();
			CGLTF.Data* data;
			CGLTF.Result result = CGLTF.ParseFile(options, scopedFileName, out data);

			if (!(result case .Success))
				return null;

			result = CGLTF.LoadBuffers(options, data, scopedFileName);

			GeometryBinding geoBinding = null;

			for (var mesh in data.Meshes)
			{
				var name = StringView(mesh.Name);

				if (name == meshName)
				{
					Log.EngineLogger.AssertDebug(primitiveIndex >= 0 && primitiveIndex < mesh.Primitives.Length);

					geoBinding = PrimitiveToGeoBinding(mesh.Primitives[primitiveIndex]);
					break;
				}
			}

			CGLTF.Free(data);

			return geoBinding;
		}

		public static GeometryBinding LoadMesh(Stream data, StringView meshName, int primitiveIndex)
		{
			// TODO: add a context to remember which buffers were loaded before so that we don't load the same data multiple times.

			uint8[] rawData = new:ScopedAlloc! uint8[data.Length];

			var dataReadResult = data.TryRead(rawData);

			if (dataReadResult case .Err(let err))
			{
				Log.EngineLogger.Error($"Failed to read data from stream. Error: {err}");
			}

			CGLTF.Options options = .();
			CGLTF.Data* modelData;
			CGLTF.Result result = CGLTF.Parse(options, (Span<uint8>)rawData, out modelData);

			if (!(result case .Success))
				return null;

			// TODO: one buffer can be used by multiple primitives, the content manager could manage the buffers

			// TODO: load with content manager

			result = CGLTF.LoadBuffers(options, modelData, (char8*)null);
			//result = LoadBuffersWithContentManager(options, modelData, meshName, Application.Get().ContentManager);

			GeometryBinding geoBinding = null;

			for (var mesh in modelData.Meshes)
			{
				var name = StringView(mesh.Name);

				//if (name == meshName)
				{
					Log.EngineLogger.AssertDebug(primitiveIndex >= 0 && primitiveIndex < mesh.Primitives.Length);

					geoBinding = PrimitiveToGeoBinding(mesh.Primitives[primitiveIndex]);
					break;
				}
			}

			CGLTF.Free(modelData);

			return geoBinding;
		}

		private static CGLTF.Result LoadBuffersWithContentManager(CGLTF.Options options, CGLTF.Data* data, StringView fileName, IContentManager contentManager)
		{
			if (data.Buffers.Length > 0 && data.Buffers[0].Data == null && data.Buffers[0].Uri == null && !data.Bin.IsEmpty)
			{
				if ((uint)data.Bin.Length < data.Buffers[0].Size)
					return .DataTooShort;

				data.Buffers[0].Data = data.Bin.Ptr;
				data.Buffers[0].DataFreeMethod = .None;
			}

			for (ref CGLTF.Buffer buffer in ref data.Buffers)
			{
				if (buffer.Data != null)
					continue;

				if (buffer.Uri == null)
					continue;

				StringView uri = StringView(buffer.Uri);

				if (uri.StartsWith("data:"))
				{
					int commaIndex = uri.IndexOf(',');

					//char* comma = strchr(uri, ',');

					if (commaIndex == -1 || commaIndex >= 7 || uri.StartsWith(";base64"))
						return .UnknownFormat;

					StringView dataView = uri.Substring(commaIndex + 1);

#unwarn
					CGLTF.Result loadBufferResult = CGLTF.LoadBuffersBase64(&options, buffer.Size, dataView.Ptr, &buffer.Data);
					buffer.DataFreeMethod = .MemoryFree;
					
					return loadBufferResult;
				}
				else
				{
					Runtime.NotImplemented();

					// TODO: Request Buffer from Content Manager

					//int index = uri.IndexOf("://");

					//if (index == -1)
					//	return .UnknownFormat;

					// TODO: load buffer file...
					//CGLTF.Result res = //cgltf_load_buffer_file(options, data->buffers[i].size, uri, gltf_path, &data->buffers[i].data);
					//buffer.DataFreeMethod = cgltf_data_free_method_file_release;

					/*if (res != cgltf_result_success)
					{
						return res;
					}*/
				}
			}

			/*

			for (cgltf_size i = 0; i < data->buffers_count; ++i)
			{
				if (data->buffers[i].data)
				{
					continue;
				}

				const char* uri = data->buffers[i].uri;

				if (uri == NULL)
				{
					continue;
				}

				if (strncmp(uri, "data:", 5) == 0)
				{
					const char* comma = strchr(uri, ',');

					if (comma && comma - uri >= 7 && strncmp(comma - 7, ";base64", 7) == 0)
					{
						cgltf_result res = cgltf_load_buffer_base64(options, data->buffers[i].size, comma + 1, &data->buffers[i].data);
						data->buffers[i].data_free_method = cgltf_data_free_method_memory_free;

						if (res != cgltf_result_success)
						{
							return res;
						}
					}
					else
					{
						return cgltf_result_unknown_format;
					}
				}
				else if (strstr(uri, "://") == NULL && gltf_path)
				{
					cgltf_result res = cgltf_load_buffer_file(options, data->buffers[i].size, uri, gltf_path, &data->buffers[i].data);
					data->buffers[i].data_free_method = cgltf_data_free_method_file_release;

					if (res != cgltf_result_success)
					{
						return res;
					}
				}
				else
				{
					return cgltf_result_unknown_format;
				}
			}
			*/

			return .Success;
		}

		/*public static EcsEntity LoadModel(String filename, Material material, EcsWorld world,
			List<AnimationClip> outClips, StringView entityName = StringView())
		{
			CGLTF.Options options = .();
			CGLTF.Data* data;
			CGLTF.Result result = CGLTF.ParseFile(options, filename, out data);

			Log.EngineLogger.Assert(result == .Success, "Failed to load model.");

			result = CGLTF.LoadBuffers(options, data, filename);

			Log.EngineLogger.Assert(result == .Success, "Failed to load buffers");
			
			(EcsEntity entity, ?) = CreateEntity(world, entityName, .InvalidEntity);

			for(var node in data.Scenes[0].Nodes)
			{
				NodesToEntities(data, node, entity, world, material, outClips);
			}
			
			CGLTF.Free(data);

			return entity;
		}*/

		private static (EcsEntity Entity, TransformComponent* Transform) CreateEntity(EcsWorld world, StringView? name, EcsEntity parent)
		{
			EcsEntity entity = world.NewEntity();

			var nameComponent = world.AssignComponent<DebugNameComponent>(entity);

			if (name != null && name.Value.Ptr != null)
			{
				nameComponent.SetName(name.Value);
			}
			else
			{
				nameComponent.SetName("Unnamed Node");
			}

			/////TODO: !!!!!!!!REPORT!!!!!!!!!!!!!
			// This works
			TransformComponent cmp = .();
			var childTransform = world.AssignComponent<TransformComponent>(entity, cmp);
			// This trashes the stack
			//var childTransform = world.AssignComponent<TransformComponent>(entity);
			childTransform.Parent = parent;

			return (entity, childTransform);
		}

		/*private static void NodesToEntities(CGLTF.Data* data, CGLTF.Node* node, EcsEntity parentEntity, EcsWorld world, Material material, List<AnimationClip> clips)
		{
			(EcsEntity entity, TransformComponent* childTransform) = CreateEntity(world, node.Name == null ? null : StringView(node.Name), parentEntity);

			if(node.HasMatrix)
			{
				childTransform.LocalTransform = *(Matrix*)&node.Matrix;
			}
			else
			{
				if(node.HasTranslation)
					childTransform.Position = *(Vector3*)&node.Translation;
				else
					childTransform.Position = .Zero;
	
				if(node.HasRotation)
					childTransform.Rotation = *(Quaternion*)&node.Rotation;
				else
					childTransform.Rotation = .Identity;
	
				if(node.HasScale)
					childTransform.Scale = *(Vector3*)&node.Scale;
				else
					childTransform.Scale = .(1, 1, 1);
			}

			// Invert the Z-Axis of the root Node to convert the coordinate system from right-handed to left-handed
			if(parentEntity == .InvalidEntity)
				childTransform.Scale *= .(1, 1, -1);

			Skeleton skeleton = null;

			if(node.Skin != null)
			{
				skeleton = ExtractSkeleton(node.Skin);

				LoadAnimationClips(data, node.Skin, skeleton, clips);
			}

			if(node.Mesh != null)
			{
				// If we have only one primitive, add it directly to the entity
				if(node.Mesh.Primitives.Length == 1)
				{
					var mesh = world.AssignComponent<MeshComponent>(entity);

					using (var geo = PrimitiveToGeoBinding(node.Mesh.Primitives[0]))
					{
						mesh.Mesh = Content.ManageAsset(geo);
					}

					if(skeleton == null)
					{
						var meshRenderer = world.AssignComponent<MeshRendererComponent>(entity);
						meshRenderer.Material = material.Handle;
					}
					else
					{
						var meshRenderer = world.AssignComponent<SkinnedMeshRendererComponent>(entity);
						meshRenderer.Material = material;
						meshRenderer.Skeleton = skeleton;
					}
				}
				// otherwise one child-entity per primitive
				else
				{
					for(var primitive in node.Mesh.Primitives)
					{
						EcsEntity meshEntity = world.NewEntity();

						var meshParent = world.AssignComponent<ParentComponent>(meshEntity);
						meshParent.Entity = entity;
						
						var mesh = world.AssignComponent<MeshComponent>(meshEntity);
						
						using (var geo = PrimitiveToGeoBinding(primitive))
						{
							mesh.Mesh = Content.ManageAsset(geo);
						}
						
						if(skeleton == null)
						{
							var meshRenderer = world.AssignComponent<MeshRendererComponent>(meshEntity);
							meshRenderer.Material = material.Handle;
						}
						else
						{
							var meshRenderer = world.AssignComponent<SkinnedMeshRendererComponent>(meshEntity);
							meshRenderer.Material = material;
							meshRenderer.Skeleton = skeleton;
						}
					}
				}
			}

			skeleton?.ReleaseRef();

			for(var child in node.Children)
			{
				NodesToEntities(data, child, entity, world, material, clips);
			}
		}*/

		public static GeometryBinding PrimitiveToGeoBinding(CGLTF.Primitive primitive)
		{
			GeometryBinding binding = new GeometryBinding();

			// primitive topology
			switch(primitive.Type)
			{
			case .Points:
				binding.SetPrimitiveTopology(.PointList);
			case .Lines:
				binding.SetPrimitiveTopology(.LineList);
			case .LineStrip:
				binding.SetPrimitiveTopology(.LineStrip);
			case .Triangles:
				binding.SetPrimitiveTopology(.TriangleList);
			case .TriangleStrip:
				binding.SetPrimitiveTopology(.TriangleStrip);
			default:
				Log.EngineLogger.Assert(false, scope $"{primitive.Type} not supported.");
			}
			
			// indices
			{
				CGLTF.Accessor* indices = primitive.Indices;

				if(indices != null)
				{
					bool is16bit = indices.ComponentType == .R_16u || indices.ComponentType == .R_16;

					IndexBuffer ib = new IndexBuffer((.)indices.Count, .Immutable, .None, is16bit ? .Index16Bit : .Index32Bit);
					
					uint8* bufferData = (uint8*)indices.BufferView.Buffer.Data;
					bufferData += indices.BufferView.Offset;

					// TODO: this is a mess
					ib.SetData<uint8>(bufferData, (.)indices.BufferView.Size);

					binding.SetIndexBuffer(ib);

					ib.ReleaseRef();
				}
			}

			bool hasNormals = false;
			bool hasTangents = false;

			// vertices
			{
				List<VertexElement> elements = scope .(primitive.Attributes.Length);
				Dictionary<void*, VertexBuffer> buffers = scope .();
				List<VertexBufferBinding> bindings = scope .();

				for(var attribute in primitive.Attributes)
				{
					{
						StringView attributeName = StringView(attribute.Name);
	
						if(attributeName.Equals("NORMAL"))
						{
							hasNormals = true;
						}
						else if(attributeName.Equals("TANGENT"))
						{
							hasTangents = true;
						}
					}

					// Get Input Element format
					Format format = FormatFromVectorComponent(attribute.Data.Type, attribute.Data.ComponentType);
					Log.EngineLogger.AssertDebug(format != .Unknown, "Vertex element format must not be \"Unknown.\"");

					VertexBuffer vertexBuffer = null;

					binding.VertexCount = (uint32)attribute.Data.Count;

					// Get vertex buffer
					{
						CGLTF.BufferView* bufferView = attribute.Data.BufferView;
						
						// if buffer doesn't exist -> create
						if(!buffers.TryGetValue(bufferView, out vertexBuffer))
						{
							vertexBuffer = new VertexBuffer(1, (uint32)bufferView.Size, .Immutable)..ReleaseRefNoDelete();

							uint8* bufferData = (uint8*)bufferView.Buffer.Data;
							bufferData += bufferView.Offset;

							vertexBuffer.SetData(bufferData, (.)bufferView.Size);

							buffers.Add(attribute.Data.BufferView, vertexBuffer);
						}

						Log.EngineLogger.AssertDebug(vertexBuffer != null);
					}

					VertexBufferBinding bufferBinding = .(vertexBuffer, (.)attribute.Data.Stride, (.)attribute.Data.Offset);

					// get slot of bufferBinding
					int bindingSlot = bindings.IndexOf(bufferBinding);

					// binding has no slot -> add to list
					if(bindingSlot == -1)
					{
						bindingSlot = bindings.Count;
						bindings.Add(bufferBinding);

						binding.SetVertexBufferSlot(bufferBinding, (.)bindingSlot);
					}

					StringView strView = .(attribute.Name);

					// Remove number from end of name
					while((*(strView.EndPtr - 1)).IsDigit || (*(strView.EndPtr - 1)) == '_')
					{
						strView.Length--;
					}

					VertexElement element = .(format, new String(strView), true, (.)attribute.Index, (.)bindingSlot);
					elements.Add(element);
				}

				// Generate normals if missing
				if(!hasNormals)
				{
					CGLTF.Accessor* positions = null;

					// Find position accessor
					for(var attribute in primitive.Attributes)
					{
						if(StringView(attribute.Name).Equals("POSITION"))
						{
							positions = attribute.Data;
							break;
						}
					}

					Log.EngineLogger.AssertDebug(positions != null, "The model appears to have no position data?!");
					
					Vector3[] normals = new Vector3[positions.Count];

					if(primitive.Indices != null)
						GenerateNormals(primitive.Indices, positions, normals);
					else
						GenerateNormals(positions, normals);

					VertexBuffer vertexBuffer = new VertexBuffer((uint32)sizeof(Vector3), (uint32)normals.Count, .Immutable);
					vertexBuffer.SetData<Vector3>(normals);
					
					bindings.Add(vertexBuffer.Binding);

					uint32 bindingSlot = (.)bindings.Count - 1;

					binding.SetVertexBufferSlot(vertexBuffer.Binding, (.)bindingSlot);
					VertexElement element = .(.R32G32B32_Float, "NORMAL", false, 0, bindingSlot);
					elements.Add(element);
				}

				// TODO: validate vertex layout somewhere else
				
				VertexElement[] vertexElements = new VertexElement[elements.Count];
				for(int i < elements.Count)
				{
					vertexElements[i] = elements[i];
				}

				VertexLayout layout = new VertexLayout(vertexElements, true);
				binding.SetVertexLayout(layout..ReleaseRefNoDelete());
			}

			// TODO: calculate tangents if missing (MikkTSpace algorithm)
			// Note: Bitangent = cross(normal, tangent.xyz) * tangent.w

			return binding;
		}

		/// Generates the normals for one triangle
		static mixin GenerateTriangleNormals(int index0, int index1, int index2, CGLTF.Accessor* positions, Vector3[] normals)
		{
			Vector3 position0 = GetEntry<Vector3>(positions, (.)index0);
			Vector3 position1 = GetEntry<Vector3>(positions, (.)index1);
			Vector3 position2 = GetEntry<Vector3>(positions, (.)index2);

			ref Vector3 normal0 = ref normals[(.)index0];
			ref Vector3 normal1 = ref normals[(.)index1];
			ref Vector3 normal2 = ref normals[(.)index2];

			Vector3 e0 = position1 - position0;
			Vector3 e1 = position2 - position0;

			Vector3 normal = Vector3.Cross(e0, e1);

			normal0 += normal;
			normal1 += normal;
			normal2 += normal;
		}

		[Inline]
		static void NormalizeNormals(Vector3[] normals)
		{
			for(int i < normals.Count)
			{
				normals[i].Normalize();
			}
		}

		/// Generates normals for the given model using indexed geometry
		static void GenerateNormals(CGLTF.Accessor* indices, CGLTF.Accessor* positions, Vector3[] normals)
		{
			/// Enumerate triangle-wise
			for(uint t = 0; t < indices.Count; t += 3)
			{
				int index0 = (.)CGLTF.AccessorReadIndex(indices, t);
				int index1 = (.)CGLTF.AccessorReadIndex(indices, t + 1);
				int index2 = (.)CGLTF.AccessorReadIndex(indices, t + 2);

				GenerateTriangleNormals!(index0, index1, index2, positions, normals);
			}

			NormalizeNormals(normals);
		}
		
		/// Generates normals for the given model using nonindexed geometry
		static void GenerateNormals(CGLTF.Accessor* positions, Vector3[] normals)
		{
			/// Enumerate triangle-wise
			for(int i = 0; i < (.)positions.Count; i += 3)
			{
				GenerateTriangleNormals!(i, i + 1, i + 2, positions, normals);
			}
			
			NormalizeNormals(normals);
		}

		static Skeleton ExtractSkeleton(CGLTF.Skin* skin)
		{
			Skeleton skeleton = new Skeleton();
			skeleton.Joints = new Joint[skin.Joints.Length];

			for(int i < skin.Joints.Length)
			{
				ref Joint joint = ref skeleton.Joints[i];

				joint.InverseBindPose = GetEntry<Matrix>(skin.InverseBindMatrices, i);

				if (skin.Joints[i].Name != null)
					joint.Name = new String(skin.Joints[i].Name);

				int parentId = skin.Joints.IndexOf(skin.Joints[i].Parent);

				Log.EngineLogger.AssertDebug(parentId < uint8.MaxValue, scope $"A skeleton must not have more than {uint8.MaxValue - 1} bones.");

				if(parentId == -1)
					joint.ParentID = uint8.MaxValue;
				else
					joint.ParentID = (uint8)parentId;
			}

			return skeleton;
		}

		static bool AnimationBelongsToSkeleton(CGLTF.Animation animation, CGLTF.Skin* skin)
		{
			for(var channel in animation.Channels)
			{
				if(skin.Joints.IndexOf(channel.TargetNode) == -1)
				{
					return false;
				}
			}

			return true;
		}

		static void LoadAnimationClips(CGLTF.Data* data, CGLTF.Skin* skin, Skeleton skeleton, List<AnimationClip> clips)
		{
			for(var animation in data.Animations)
			{
				if(!AnimationBelongsToSkeleton(animation, skin))
					continue;

				AnimationClip clip = new AnimationClip(skeleton);
				clips.Add(clip);
				clip.IsLooping = true;

				for(var channel in animation.Channels)
				{
					int nodeIndex = skin.Joints.IndexOf(channel.TargetNode);

					Log.EngineLogger.AssertDebug(nodeIndex != -1);

					ref JointAnimation jointAnimation = ref clip.JointAnimations[nodeIndex];

					if(jointAnimation == null)
						jointAnimation = new JointAnimation();

					Log.EngineLogger.AssertDebug(channel.Sampler.Input.Count == channel.Sampler.Output.Count);

					int samples = (int)channel.Sampler.Input.Count;

					Log.EngineLogger.AssertDebug(channel.Sampler.Input.ComponentType == .R_32f);
					Log.EngineLogger.AssertDebug(channel.Sampler.Input.Type == .Scalar);

					InterpolationMode interpolationMode;

					switch(channel.Sampler.Interpolation)
					{
					case .Step:
						interpolationMode = .Step;
					case .Linear:
						interpolationMode = .Linear;
					case .CubicSpline:
						interpolationMode = .CubicSpline;
					}

					switch(channel.TargetPath)
					{
					case .Translation:
						jointAnimation.TranslationChannel = new .(samples, interpolationMode);

						Log.EngineLogger.AssertDebug(channel.Sampler.Output.ComponentType == .R_32f);
						Log.EngineLogger.AssertDebug(channel.Sampler.Output.Type == .Vec3);

						for(int i < samples)
						{
							float timeStamp = GetEntry<float>(channel.Sampler.Input, i);
							Vector3 sample = GetEntry<Vector3>(channel.Sampler.Output, i);
							
							jointAnimation.TranslationChannel.TimeStamps[i] = timeStamp;
							jointAnimation.TranslationChannel.Values[i] = sample;
						}
					case .Rotation:
						jointAnimation.RotationChannel = new .(samples, interpolationMode);

						Log.EngineLogger.AssertDebug(channel.Sampler.Output.ComponentType == .R_32f);
						Log.EngineLogger.AssertDebug(channel.Sampler.Output.Type == .Vec4);

						for(int i < samples)
						{
							float timeStamp = GetEntry<float>(channel.Sampler.Input, i);
							Quaternion sample = GetEntry<Quaternion>(channel.Sampler.Output, i);

							jointAnimation.RotationChannel.TimeStamps[i] = timeStamp;
							jointAnimation.RotationChannel.Values[i] = sample;
						}
					case .Scale:
						jointAnimation.ScaleChannel = new .(samples, interpolationMode);

						Log.EngineLogger.AssertDebug(channel.Sampler.Output.ComponentType == .R_32f);
						Log.EngineLogger.AssertDebug(channel.Sampler.Output.Type == .Vec3);

						for(int i < samples)
						{
							float timeStamp = GetEntry<float>(channel.Sampler.Input, i);
							Vector3 sample = GetEntry<Vector3>(channel.Sampler.Output, i);

							jointAnimation.ScaleChannel.TimeStamps[i] = timeStamp;
							jointAnimation.ScaleChannel.Values[i] = sample;
						}
					default:
						Log.EngineLogger.Error($"Unknown channel target path \"{channel.TargetPath}\"");
					}

					clip.Duration = Math.Max(clip.Duration, jointAnimation.Duration);
				}
			}
		}

		static T GetEntry<T>(CGLTF.Accessor* accessor, int index)
		{
			Log.EngineLogger.AssertDebug((uint)index < accessor.Count);
			
			T result = ?;
			
			switch(typeof(T))
			{
			case typeof(float):
				CGLTF.AccessorReadFloat(accessor, (uint)index, (float*)&result, 1);
			case typeof(Vector2):
				CGLTF.AccessorReadFloat(accessor, (uint)index, (float*)&result, 2);
			case typeof(Vector3):
				CGLTF.AccessorReadFloat(accessor, (uint)index, (float*)&result, 3);
			case typeof(Vector4), typeof(Quaternion):
				CGLTF.AccessorReadFloat(accessor, (uint)index, (float*)&result, 4);
			case typeof(Matrix):
				CGLTF.AccessorReadFloat(accessor, (uint)index, (float*)&result, 16);
			case typeof(uint16):
				CGLTF.AccessorReadUint(accessor, (uint)index, (uint32*)&result, 2);
			case default:
				uint8* data = (uint8*)accessor.BufferView.Buffer.Data;

				data += accessor.BufferView.Offset;

				data += accessor.Offset;

				data += accessor.Stride * (uint)index;

				result = *(T*)data;
			}

			return result;
			
			/*
			uint8* data = (uint8*)accessor.BufferView.Buffer.Data;

			data += accessor.BufferView.Offset;

			data += accessor.Offset;

			data += accessor.Stride * (uint)index;
			
			return *(T*)data;
			*/
		}

		/**
		 * Converts the vector and component type to the corresponding Format.
		 */
		static Format FormatFromVectorComponent(CGLTF.Type vectorType, CGLTF.ComponentType componentType)
		{
			switch((vectorType, componentType))
			{
			case (.Scalar, .R_8):
				return .R8_SInt;
			case (.Scalar, .R_8u):
				return .R8_UInt;
			case (.Scalar, .R_16):
				return .R16_SInt;
			case (.Scalar, .R_16u):
				return .R16_UInt;
			case (.Scalar, .R_32u):
				return .R32_UInt;
			case (.Scalar, .R_32f):
				return .R32_Float;

			case (.Vec2, .R_8):
				return .R8G8_SInt;
			case (.Vec2, .R_8u):
				return .R8G8_UInt;
			case (.Vec2, .R_16):
				return .R16G16_SInt;
			case (.Vec2, .R_16u):
				return .R16G16_UInt;
			case (.Vec2, .R_32u):
				return .R32G32_UInt;
			case (.Vec2, .R_32f):
				return .R32G32_Float;
				
			//case (.Vec3, .R_8):	
			//case (.Vec3, .R_8u):
			//case (.Vec3, .R_16):
			//case (.Vec3, .R_16u):
			case (.Vec3, .R_32u):
				return .R32G32B32_UInt;
			case (.Vec3, .R_32f):
				return .R32G32B32_Float;
				
			case (.Vec4, .R_8):
				return .R8G8B8A8_SInt;
			case (.Vec4, .R_8u):
				return .R8G8B8A8_UInt;
			case (.Vec4, .R_16):
				return .R16G16B16A16_SInt;
			case (.Vec4, .R_16u):
				return .R16G16B16A16_UInt;
			case (.Vec4, .R_32u):
				return .R32G32B32A32_UInt;
			case (.Vec4, .R_32f):
				return .R32G32B32A32_Float;
				
			case (.Mat4, .R_32f):
				return .R32G32B32A32_Float;

			default:
				Log.EngineLogger.Assert(false, scope $"Unhandled vector - componenttype combination. ({vectorType}, {componentType})");
			}

			return .Unknown;
		}
	}
}

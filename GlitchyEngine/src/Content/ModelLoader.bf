using System;
using System.Collections;
using cgltf;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using GlitchyEngine.Renderer.Animation;
using GlitchyEngine.World;

namespace GlitchyEngine.Content
{
	public static class ModelLoader
	{
		static readonly Matrix RightToLeftHand = .Scaling(1, 1, -1);

		public static void LoadModel(String filename, Effect validationEffect, Material material, EcsWorld world,
			List<AnimationClip> outClips)
		{
			CGLTF.Options options = .();
			CGLTF.Data* data;
			CGLTF.Result result = CGLTF.ParseFile(options, filename, out data);
			
			Log.EngineLogger.Assert(result == .Success, "Failed to load model.");

			result = CGLTF.LoadBuffers(options, data, filename);

			Log.EngineLogger.Assert(result == .Success, "Failed to load buffers");

			for(var node in data.Scenes[0].Nodes)
			{
				NodesToEntities(data, node, null, world, validationEffect, material, outClips);
			}
			
			CGLTF.Free(data);
		}

		private static void NodesToEntities(CGLTF.Data* data, CGLTF.Node* node, EcsEntity? parentEntity, EcsWorld world, Effect validationEffect, Material material, List<AnimationClip> clips)
		{
			EcsEntity entity = world.NewEntity();

//#if DEBUG
			var nameComponent = world.AssignComponent<DebugNameComponent>(entity);

			if (node.Name != null)
			{
				nameComponent.SetName(StringView(node.Name));
			}
			else
			{
				nameComponent.SetName("Unnamed Node");
			}
//#endif

			if(parentEntity.HasValue)
			{
				var childParent = world.AssignComponent<ParentComponent>(entity);
				childParent.Entity = parentEntity.Value;
			}

			var childTransform = world.AssignComponent<TransformComponent>(entity);

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
			if(parentEntity == null)
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

					using (var geo = PrimitiveToGeoBinding(node.Mesh.Primitives[0], validationEffect))
					{
						mesh.Mesh = geo;
					}

					if(skeleton == null)
					{
						var meshRenderer = world.AssignComponent<MeshRendererComponent>(entity);
						meshRenderer.Material = material;
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
						mesh.Mesh = PrimitiveToGeoBinding(primitive, validationEffect);
						
						if(skeleton == null)
						{
							var meshRenderer = world.AssignComponent<MeshRendererComponent>(meshEntity);
							meshRenderer.Material = material;
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
				NodesToEntities(data, child, entity, world, validationEffect, material, clips);
			}
		}

		public static GeometryBinding PrimitiveToGeoBinding(CGLTF.Primitive primitive, Effect validationEffect)
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
					while((*(strView.EndPtr - 1)).IsDigit)
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

				VertexLayout layout = new VertexLayout(vertexElements, true, validationEffect.VertexShader);
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

using System;
using System.Collections;
using cgltf;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using GlitchyEngine.Renderer.Animation;

namespace GlitchyEngine.Content
{
	public static class ModelLoader
	{
		static readonly Matrix RightToLeftHand = .Scaling(1, 1, -1);

		public static void LoadModel(String filename, GraphicsContext context, Effect validationEffect, List<(Matrix Transform, GeometryBinding Model)> output, out Skeleton skeleton, out AnimationClip clip)
		{
			skeleton = null;
			clip = null;

			CGLTF.Options options = .();
			CGLTF.Data* data;
			CGLTF.Result result = CGLTF.ParseFile(options, filename, out data);
			
			Log.EngineLogger.Assert(result == .Success, "Failed to load model.");

			result = CGLTF.LoadBuffers(options, data, filename);

			Log.EngineLogger.Assert(result == .Success, "Failed to load buffers");

			for(var node in data.Nodes)
			{
				if(node.Mesh != null)
				{
					Matrix transform = ?;
					CGLTF.NodeTransformLocal(&node, (float*)&transform);

					transform = RightToLeftHand * transform;

					for(var primitive in node.Mesh.Primitives)
					{
						GeometryBinding binding = ModelLoader.PrimitiveToGeoBinding(context, primitive, validationEffect);

						output.Add((transform, binding));
					}
				}

				if(node.Skin != null)
				{
					(skeleton, clip) = ExtractBonestuff(node.Skin, data);
				}
			}

			/* TODO make awesome stuff */
			CGLTF.Free(data);
		}

		public static GeometryBinding PrimitiveToGeoBinding(GraphicsContext context, CGLTF.Primitive primitive, Effect validationEffect)
		{
			GeometryBinding binding = new GeometryBinding(context);

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

					IndexBuffer ib = new IndexBuffer(context, (.)indices.Count, .Immutable, .None, is16bit ? .Index16Bit : .Index32Bit);
					
					uint8* bufferData = (uint8*)indices.BufferView.Buffer.Data;
					bufferData += indices.BufferView.Offset;

					ib.SetData<uint8>(bufferData, (.)indices.BufferView.Size);

					binding.SetIndexBuffer(ib);

					ib.ReleaseRef();
				}
			}

			// vertices
			{
				List<VertexElement> elements = scope .(primitive.Attributes.Length);
				Dictionary<CGLTF.BufferView*, VertexBuffer> buffers = scope .();
				List<VertexBufferBinding> bindings = scope .();

				for(var attribute in primitive.Attributes)
				{
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
							vertexBuffer = new VertexBuffer(context, 1, (uint32)bufferView.Size, .Immutable)..ReleaseRefNoDelete();

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

					while((*(strView.EndPtr - 1)).IsDigit)
					{
						strView.Length--;
					}

					VertexElement element = .(format, new String(strView), true, (.)attribute.Index, (.)bindingSlot);
					elements.Add(element);
				}

				VertexElement[] vertexElements = new VertexElement[elements.Count];
				for(int i < elements.Count)
				{
					vertexElements[i] = elements[i];
				}

				// TODO: validate vertex layout somewhere else
				
				VertexLayout layout = new VertexLayout(context, vertexElements, true, validationEffect.VertexShader);
				binding.SetVertexLayout(layout..ReleaseRefNoDelete());
			}

			// TODO: calculate normals if missing
			// TODO: calculate tangents if missing (MikkTSpace algorithm)
			// Note: Bitangent = cross(normal, tangent.xyz) * tangent.w

			return binding;
		}

		static (Skeleton, AnimationClip) ExtractBonestuff(CGLTF.Skin* skin, CGLTF.Data* data)
		{
			Skeleton skeleton = new Skeleton();
			skeleton.Joints = new Joint[skin.Joints.Length];

			AnimationClip testClip = new AnimationClip();
			testClip.Skeleton = skeleton;
			testClip.FramesPerSecond = 0;
			testClip.JointAnimations = new JointAnimation[skeleton.Joints.Count];
			//testClip.Samples = new AnimationSample[1];
			//testClip.Samples[0].JointPose = new JointPose[skeleton.Joints.Count];
			testClip.IsLooping = true;

			for(int i < skin.Joints.Length)
			{
				ref Joint joint = ref skeleton.Joints[i];



				joint.InverseBindPose = GetEntry<Matrix>(skin.InverseBindMatrices, i);

				joint.Name = new String(skin.Joints[i].Name);

				int parentId = skin.Joints.IndexOf(skin.Joints[i].Parent);

				Log.EngineLogger.AssertDebug(parentId < uint8.MaxValue, scope $"A skeleton must not have more than {uint8.MaxValue - 1} bones.");

				if(parentId == -1)
					joint.ParentID = uint8.MaxValue;
				else
					joint.ParentID = (uint8)parentId;
			}

			for(var channel in data.Animations[0].Channels)
			{
				int nodeIndex = skin.Joints.IndexOf(channel.TargetNode);

				Log.EngineLogger.AssertDebug(nodeIndex != -1);

				ref JointAnimation jointAnimation = ref testClip.JointAnimations[nodeIndex];

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
						/*
						float timeStamp = GetEntry<float>(channel.Sampler.Input, i);
						float timeStamp2 = ?;
						CGLTF.AccessorReadFloat(channel.Sampler.Input, (uint)i, (float*)&timeStamp2, 1);

						Log.EngineLogger.Assert(timeStamp == timeStamp2);

						Vector3 sample2 = ?;
						CGLTF.AccessorReadFloat(channel.Sampler.Output, (uint)i, (float*)&sample2, 3);
						
						Log.EngineLogger.Assert(sample == sample2);
						*/
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

				//channel.

				//

				//testClip.JointAnimations[i].
				testClip.Duration = Math.Max(testClip.Duration, jointAnimation.Duration);
			}

			return (skeleton, testClip);
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

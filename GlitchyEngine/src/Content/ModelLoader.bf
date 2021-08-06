using System;
using System.Collections;
using cgltf;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;

namespace GlitchyEngine.Content
{
	public static class ModelLoader
	{
		public static void LoadModel(String filename, GraphicsContext context, Effect validationEffect, List<(Matrix Transform, GeometryBinding Model)> output)
		{
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
					CGLTF.NodeTransformWorld(&node, (float*)&transform);

					for(var primitive in node.Mesh.Primitives)
					{
						GeometryBinding binding = ModelLoader.PrimitiveToGeoBinding(context, primitive, validationEffect);

						output.Add((transform, binding));
					}
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

					VertexElement element = .(format, new String(attribute.Name), true, (.)attribute.Index, (.)bindingSlot);
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

			return binding;
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

using GlitchyEngine.Math;
using GlitchyEngine.World;
using System.Collections;
using System;

namespace GlitchyEngine.Renderer
{
	public class Renderer
	{
		struct SceneConstants
		{
			public Matrix ViewProjection;
			public Vector3 CameraPosition;
			public RenderTargetGroup CameraTarget;
			public RenderTargetGroup CompositionTarget;
		}

		struct ObjectConstants
		{
			public Matrix Transform;
		}

		class GBuffer
		{
			private uint32 _width;
			private uint32 _height;
			
			public uint32 Width => _width;
			public uint32 Height => _height;

			public Int2 Size => .(_width, _height);

			public RenderTargetGroup Target ~ _?.ReleaseRef();

			public void EnsureSize(uint32 width, uint32 height)
			{
				if (width <= _width && height <= _height)
					return;

				if (_width == 0 || _height == 0)
				{
					SamplerStateDescription desc = .();
					desc.MinFilter = .Point;
					desc.MagFilter = .Point;

					RenderTargetGroupDescription targetDesc = .(width, height,
						TargetDescription[](
							.(RenderTargetFormat.R8G8B8A8_UNorm){SamplerDescription = desc},
							.(RenderTargetFormat.R16G16B16A16_SNorm){SamplerDescription = desc},
							.(RenderTargetFormat.R16G16B16A16_SNorm){SamplerDescription = desc},
							.(RenderTargetFormat.R32G32B32A32_Float){SamplerDescription = desc},
							.(RenderTargetFormat.R8G8B8A8_UNorm){SamplerDescription = desc},
							.(RenderTargetFormat.R32_UInt){SamplerDescription = desc, ClearColor = .UInt(uint32.MaxValue)},
						),
						TargetDescription(.D24_UNorm_S8_UInt){
							SamplerDescription = desc,
							ClearColor = .DepthStencil(1.0f, 0)
						});
					Target = new RenderTargetGroup(targetDesc);
				}

				_width = width;
				_height = height;

				Target.Resize(_width, _height);
			}

			public void Bind()
			{
				RenderCommand.SetRenderTargetGroup(Target);
				RenderCommand.BindRenderTargets();
			}

			public void Clear()
			{
				RenderCommand.Clear(Target, .ColorDepth);
			}
		}

		static internal GraphicsContext _context;

		static SceneConstants _sceneConstants;

		static Effect LineEffect;
		static VertexBuffer LineVertices;
		static GeometryBinding LineGeometry;

		static GBuffer _gBuffer;
		static Effect TestFullscreenEffect;
		static Effect s_tonemappingEffect;

		static BlendState _gBufferBlend;
		static BlendState _lightBlend;
		static DepthStencilState _fullscreenDepthState;

		static Buffer _sceneBuffer;
		static Buffer _objectBuffer;

		[Ordered]
		struct ObjectConstantsBuffer
		{
			public Matrix Transform;
			public Matrix4x3 Transform_InvT;
			public uint32 EntityId;

			private Vector3 _padding;
		}

		public static void Init(GraphicsContext context, EffectLibrary effectLibrary)
		{
			Debug.Profiler.ProfileFunction!();

			_context = context..AddRef();
			
			RenderCommand.Init();
			Renderer2D.Init();
			FullscreenQuad.Init();

			InitLineRenderer(effectLibrary);
			InitDeferredRenderer(effectLibrary);
		}

		public static void Deinit()
		{
			Debug.Profiler.ProfileFunction!();

			DeinitDeferredRenderer();

			DeinitLineRenderer();
			
			FullscreenQuad.Deinit();
			Renderer2D.Deinit();

			_context.ReleaseRef();
		}

		static void InitLineRenderer(EffectLibrary effectLibrary)
		{
			Debug.Profiler.ProfileFunction!();

			LineEffect = effectLibrary.Load("content\\Shaders\\lineShader.hlsl");

			LineGeometry = new GeometryBinding();
			LineGeometry.SetPrimitiveTopology(.LineList);
			
			Vector4[2] vertices = .(.Zero, .Zero);
			LineVertices = new VertexBuffer(sizeof(Vector4), 2, .Dynamic, .Write);
			LineVertices.SetData<Vector4>(vertices, 0, .WriteDiscard);
			LineGeometry.SetVertexBufferSlot(LineVertices, 0);
			
			uint16[2] indices = .(0, 1);
			IndexBuffer indexBuffer = new IndexBuffer(2, .Immutable);
			indexBuffer.SetData(indices);
			LineGeometry.SetIndexBuffer(indexBuffer);
			indexBuffer.ReleaseRef();

			VertexElement[] vertexElements = new VertexElement[1];
			vertexElements[0] = .(.R32G32B32_Float, "POSITION");
			VertexLayout layout = new VertexLayout(vertexElements, true);
			LineGeometry.SetVertexLayout(layout..ReleaseRefNoDelete());
		}

		static void DeinitLineRenderer()
		{
			LineVertices.ReleaseRef();
			LineGeometry.ReleaseRef();
			LineEffect.ReleaseRef();
		}

		static void InitDeferredRenderer(EffectLibrary effectLibrary)
		{
			TestFullscreenEffect = effectLibrary.Load("content\\Shaders\\simpleLight.hlsl");
			s_tonemappingEffect = effectLibrary.Load("content\\Shaders\\SimpleTonemapping.hlsl");

			_gBuffer = new GBuffer();
			BlendStateDescription gBufferBlendDesc = .Default;
			_gBufferBlend = new BlendState(gBufferBlendDesc);

			BlendStateDescription lightBlendDesc = .Default;
			lightBlendDesc.RenderTarget[0] = .(){
				BlendEnable = true,
				SourceBlend = .One,
				DestinationBlend = .One,
				BlendOperation = .Add,
				SourceBlendAlpha = .One,
				DestinationBlendAlpha = .Zero,
				BlendOperationAlpha = .Add,
				RenderTargetWriteMask = .All
			};
			_lightBlend = new BlendState(lightBlendDesc);

			DepthStencilStateDescription dsDesc = .Default;
			dsDesc.DepthEnabled = false;
			_fullscreenDepthState = new DepthStencilState(dsDesc);

			BufferDescription sceneBufferDesc = .(sizeof(Matrix), .Constant, .Dynamic, .Write);
			_sceneBuffer = new Buffer(sceneBufferDesc);

			BufferDescription objectBufferDesc = .(sizeof(ObjectConstantsBuffer), .Constant, .Dynamic, .Write);
			_objectBuffer = new Buffer(objectBufferDesc);
		}

		static void DeinitDeferredRenderer()
		{
			_objectBuffer.ReleaseRef();
			_sceneBuffer.ReleaseRef();

			_fullscreenDepthState.ReleaseRef();
			_lightBlend.ReleaseRef();
			_gBufferBlend.ReleaseRef();
			delete _gBuffer;

			s_tonemappingEffect.ReleaseRef();
			TestFullscreenEffect.ReleaseRef();
		}

		// [Obsolete("", false)]
		public static void BeginScene(OldCamera camera)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_sceneConstants.ViewProjection = camera.ViewProjection;
		}

		public static void BeginScene(Camera camera, Matrix transform, RenderTargetGroup renderTarget, RenderTargetGroup finalTarget)
		{
			Debug.Profiler.ProfileRendererFunction!();
			
			Matrix viewProjection = camera.Projection * Matrix.Invert(transform);
			_sceneConstants.ViewProjection = viewProjection;
			_sceneConstants.CameraPosition = transform.Translation;
			_sceneConstants.CameraTarget = renderTarget;
			_sceneConstants.CompositionTarget = finalTarget;

			_sceneBuffer.SetData<Matrix>(viewProjection);
		}

		public static void BeginScene(EditorCamera camera, RenderTargetGroup finalTarget)
		{
			Debug.Profiler.ProfileRendererFunction!();
			
			Matrix viewProjection = camera.Projection * camera.View;
			_sceneConstants.ViewProjection = viewProjection;
			_sceneConstants.CameraPosition = camera.Position;
			_sceneConstants.CameraTarget = camera.RenderTarget;
			_sceneConstants.CompositionTarget = finalTarget;

			_sceneBuffer.SetData<Matrix>(viewProjection, 0, .WriteDiscard);
		}

		public static int SortMeshes(SubmittedMesh left, SubmittedMesh right)
		{
			// TODO: Once Material "inheritance" is ready we could perhaps check how similar materials are (e.g. shared textures/variables/etc...)
			// Similar thing could be done for Meshes. Both would probably require a different way to sort however?...

			int cmp = (int)Internal.UnsafeCastToPtr(left.Material) <=> (int)Internal.UnsafeCastToPtr(right.Material);

			// Material equal: Sort by Mesh
			if (cmp == 0)
			{
				cmp = (int)Internal.UnsafeCastToPtr(left.Mesh) <=> (int)Internal.UnsafeCastToPtr(right.Mesh);

				// Material and Mesh equal: sort by distance
				if (cmp == 0)
				{
					float distLeftSq = Vector3.DistanceSquared(_sceneConstants.CameraPosition, left.Transform.Translation);
					float distRightSq = Vector3.DistanceSquared(_sceneConstants.CameraPosition, right.Transform.Translation);

					// Whether or not the values are squared doesn't affect the order (because square(root) is a monotonic function)
					cmp = distLeftSq <=> distRightSq;
				}
			}

			return 0;
		}

		public static void EndScene()
		{
			Debug.Profiler.ProfileRendererFunction!();

			{
				Debug.Profiler.ProfileRendererScope!("Sort Meshes");

				_queue.Sort(scope => SortMeshes);
			}
			// Deferred renderer:

			// TODO: foreach light: draw shadow map
			
			// foreach camera:
			// {

			{
				Debug.Profiler.ProfileRendererScope!("Draw GBuffer");
				
				_gBuffer.EnsureSize(_sceneConstants.CameraTarget.Width, _sceneConstants.CameraTarget.Height);
				_gBuffer.Clear();
				RenderCommand.UnbindRenderTargets();
				_gBuffer.Bind();

				RenderCommand.SetViewport(0, 0, _sceneConstants.CameraTarget.Width, _sceneConstants.CameraTarget.Height);

				RenderCommand.SetBlendState(_gBufferBlend);

				for (SubmittedMesh entry in _queue)
				{
					Debug.Profiler.ProfileRendererScope!("Draw Mesh");

					{
						Debug.Profiler.ProfileRendererScope!("SetVariables");

						ObjectConstantsBuffer objectData;
						objectData.Transform = entry.Transform;

						Matrix4x3 mat = Matrix4x3((Matrix3x3)(entry.Transform).Invert().Transpose());
						objectData.Transform_InvT = mat;

						objectData.EntityId = entry.EntityId;

						_objectBuffer.SetData(objectData, 0, .WriteDiscard);

						entry.Material.Effect.Buffers.TryReplaceBuffer("SceneConstants", _sceneBuffer);
						entry.Material.Effect.Buffers.TryReplaceBuffer("ObjectConstants", _objectBuffer);

						/*entry.Material.SetVariable("ViewProjection", _sceneConstants.ViewProjection);

						entry.Material.SetVariable("Transform", entry.Transform);

						entry.Material.SetVariable("EntityId", entry.EntityId);

						Matrix3x3 mat = (Matrix3x3)(entry.Transform).Invert().Transpose();
						entry.Material.SetVariable("Transform_InvT", mat);*/
					}

					entry.Material.Bind(_context);

					entry.Mesh.Bind();
					RenderCommand.DrawIndexed(entry.Mesh);
				}
			}
			
			{
				Debug.Profiler.ProfileRendererScope!("Draw Lights");

				RenderCommand.UnbindRenderTargets();
				RenderCommand.SetRenderTargetGroup(_sceneConstants.CameraTarget);
				RenderCommand.BindRenderTargets();

				RenderCommand.Clear(_sceneConstants.CameraTarget, .ColorDepth);

				RenderCommand.SetBlendState(_lightBlend);
				RenderCommand.SetDepthStencilState(_fullscreenDepthState);

				// Scaling to make sure that only the part of the gbuffer that we actually used gets rendered into the viewport.
				Vector2 scaling = Vector2(_sceneConstants.CameraTarget.Width, _sceneConstants.CameraTarget.Height) / (Vector2)_gBuffer.Size;

				for (SubmittedLight light in _lights)
				{
					Debug.Profiler.ProfileRendererScope!("Draw Light");

					Vector3 lightDir = -light.Transform.Forward;

					TestFullscreenEffect.SetTexture("GBuffer_Albedo", _gBuffer.Target, 0);
					TestFullscreenEffect.SetTexture("GBuffer_Normal", _gBuffer.Target, 1);
					TestFullscreenEffect.SetTexture("GBuffer_Tangent", _gBuffer.Target, 2);
					TestFullscreenEffect.SetTexture("GBuffer_Position", _gBuffer.Target, 3);
					TestFullscreenEffect.SetTexture("GBuffer_Material", _gBuffer.Target, 4);
		
					TestFullscreenEffect.Variables["LightColor"].SetData(light.Light.Color);
					TestFullscreenEffect.Variables["Illuminance"].SetData(light.Light.Illuminance);
					TestFullscreenEffect.Variables["LightDir"].SetData(lightDir);

					TestFullscreenEffect.Variables["CameraPos"].SetData(_sceneConstants.CameraPosition);

					TestFullscreenEffect.Variables["Scaling"].SetData(scaling);
		
					TestFullscreenEffect.Bind(_context);
		
					FullscreenQuad.Draw();
				}

				_lights.Clear();

				// Copy EntityIDs to compositionTarget
				_gBuffer.Target.CopyTo(_sceneConstants.CompositionTarget, 1, Int2.Zero, Int2(_sceneConstants.CameraTarget.Width, _sceneConstants.CameraTarget.Height), Int2.Zero, 5);

				RenderCommand.SetBlendState(_gBufferBlend);

				RenderCommand.UnbindRenderTargets();
				RenderCommand.SetRenderTargetGroup(_sceneConstants.CompositionTarget, true);
				RenderCommand.BindRenderTargets();

				// TODO: Postprocessing effects
				s_tonemappingEffect.SetTexture("CameraTarget", _sceneConstants.CameraTarget, 0);
				s_tonemappingEffect.Bind(_context);

				FullscreenQuad.Draw();

				RenderCommand.UnbindTextures();
			}

			// TODO: Draw lights to camera target
			// }

			// Queue entries increase the reference counter of the mesh/material thus we have to dispose of them.
			ClearAndDisposeItems!(_queue);
		}

		public static void Submit(GeometryBinding geometry, Effect effect, Matrix transform = .Identity)
		{
			Debug.Profiler.ProfileRendererFunction!();

			//effect.PixelShader?.Buffers.TryReplaceBuffer("SceneConstants", _sceneConstants);
			//effect.VertexShader?.Buffers.TryReplaceBuffer("SceneConstants", _sceneConstants);

			//_objectConstants.Data.Transform = transform;
			//_objectConstants.Update();

			//effect.PixelShader?.Buffers.TryReplaceBuffer("ObjectConstants", _objectConstants);
			//effect.VertexShader?.Buffers.TryReplaceBuffer("ObjectConstants", _objectConstants);
			
			effect.Variables["ViewProjection"].SetData(_sceneConstants.ViewProjection);
			effect.Variables["Transform"].SetData(transform);

			effect.Bind(_context);

			geometry.Bind();
			RenderCommand.DrawIndexed(geometry);
		}

		struct SubmittedMesh : IDisposable
		{
			public GeometryBinding Mesh;
			public Material Material;
			public Matrix Transform;
			public uint32 EntityId;

			public this(GeometryBinding mesh, Material material, Matrix transform, uint32 id)
			{
				Mesh = mesh..AddRef();
				Material = material..AddRef();
				Transform = transform;
				EntityId = id;
			}

			public void Dispose()
			{
				Mesh.ReleaseRef();
				Material.ReleaseRef();
			}
		}

		struct SubmittedLight
		{
			public SceneLight Light;
			public Matrix Transform;

			public this(SceneLight light, Matrix transform)
			{
				Light = light;
				Transform = transform;
			}
		}

		private static List<SubmittedMesh> _queue = new .(10000) ~ DeleteContainerAndDisposeItems!(_);
		private static List<SubmittedLight> _lights = new .(100) ~ delete _;

		public static void Submit(GeometryBinding geometry, Material material, Matrix transform = .Identity)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_queue.Add(SubmittedMesh(geometry, material, transform, uint32.MaxValue));
		}

		public static void Submit(GeometryBinding geometry, Material material, EcsEntity entity, Matrix transform = .Identity)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_queue.Add(SubmittedMesh(geometry, material, transform, entity.[Friend]Index));
		}

		public static void Submit(SceneLight light, Matrix transform = .Identity)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_lights.Add(SubmittedLight(light, transform));
		}

		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		 */
		public static void DrawLine(Vector3 start, Vector3 end, Color color)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(end, 1.0f), (ColorRGBA)color, .Identity);
		}
		
		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		 * @param transform A transform matrix transforming the line.
		 */
		public static void DrawLine(Vector3 start, Vector3 end, ColorRGBA color, Matrix transform)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(end, 1.0f), color, transform);
		}
		
		/** @brief Draws a ray.
		 * @param start The start point of the ray.
		 * @param direction The direction of the ray.
		 * @param color The color of the ray.
		 */
		public static void DrawRay(Vector3 start, Vector3 direction, ColorRGBA color)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(direction, 0.0f), color, .Identity);
		}

		/** @brief Draws a ray.
		 * @param start The start point of the ray.
		 * @param direction The direction of the ray.
		 * @param color The color of the ray.
		 * @param transform A transform matrix transforming the ray.
		 */
		public static void DrawRay(Vector3 start, Vector3 direction, ColorRGBA color, Matrix transform)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(direction, 0.0f), color, transform);
		}
		
		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		 * @param transform A transform matrix transforming the line.
		 */
		public static void DrawLine(Vector4 start, Vector4 end, ColorRGBA color, Matrix transform)
		{
			Debug.Profiler.ProfileRendererFunction!();

			LineVertices.SetData(Vector4[2](start, end), 0, .WriteDiscard);
			LineEffect.Variables["ViewProjection"].SetData(_sceneConstants.ViewProjection * transform);
			LineEffect.Variables["Color"].SetData(color);

			LineEffect.Bind(_context);

			LineGeometry.Bind();
			RenderCommand.DrawIndexed(LineGeometry);
		}
		
		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		* @param transform A transform matrix transforming the line.
		 * @param viewProjection The observing cameras viewprojection
		 */
		public static void DrawLine(Vector4 start, Vector4 end, ColorRGBA color, Matrix transform, Matrix viewProjection)
		{
			Debug.Profiler.ProfileRendererFunction!();

			LineVertices.SetData(Vector4[2](start, end), 0, .WriteDiscard);
			LineEffect.Variables["ViewProjection"].SetData(viewProjection * transform);
			LineEffect.Variables["Color"].SetData(color);

			LineEffect.Bind(_context);

			LineGeometry.Bind();
			RenderCommand.DrawIndexed(LineGeometry);
		}
	}
}

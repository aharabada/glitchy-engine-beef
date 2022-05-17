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
			public RenderTarget2D CameraTarget;
			public RenderTarget2D CompositionTarget;
		}

		struct ObjectConstants
		{
			public Matrix Transform;
		}

		class GBuffer
		{
			private uint32 _width;
			private uint32 _height;
			
			public DepthStencilTarget DepthStencil;

			public uint32 Width => _width;
			public uint32 Height => _height;

			public Int2 Size => .(_width, _height);

			// RGB: Albedo.rgb A: ?
			public RenderTarget2D Albedo ~ _?.ReleaseRef();
			// RG: TextureNormal.xy BA: GeometryNormal.xy
			public RenderTarget2D Normal ~ _?.ReleaseRef();
			// R: GeometryNormal.z GBA: GeometryTangent.xyz
			public RenderTarget2D Tangent ~ _?.ReleaseRef();
			// RGB: Worldspace Position A: ?
			public RenderTarget2D Position ~ _?.ReleaseRef();
			// R: Metallicity G: Roughness B: Ambient A: ?
			public RenderTarget2D Material ~ _?.ReleaseRef();

			public void EnsureSize(uint32 width, uint32 height)
			{
				if (width <= _width && height <= _height)
					return;

				if (_width == 0 || _height == 0)
				{
					// Note: Depth-Buffer in Color-Target for convenience
					RenderTarget2DDescription albedoDesc = .(.R8G8B8A8_UNorm, width, height, 1, 1, .D24_UNorm_S8_UInt);
					Albedo = new RenderTarget2D(albedoDesc);

					RenderTarget2DDescription normalDesc = .(.R16G16B16A16_SNorm, width, height);
					Normal = new RenderTarget2D(normalDesc);
					
					RenderTarget2DDescription tangentDesc = .(.R16G16B16A16_SNorm, width, height);
					Tangent = new RenderTarget2D(tangentDesc);

					RenderTarget2DDescription positionDesc = .(.R32G32B32A32_Float, width, height);
					Position = new RenderTarget2D(positionDesc);

					RenderTarget2DDescription materialDesc = .(.R8G8B8A8_UNorm, width, height);
					Material = new RenderTarget2D(materialDesc);
				}

				_width = width;
				_height = height;

				Albedo.Resize(_width, _height);
				Normal.Resize(_width, _height);
				Tangent.Resize(_width, _height);
				Position.Resize(_width, _height);
				Material.Resize(_width, _height);

				DepthStencil = Albedo.DepthStencilTarget;
			}

			public void Bind()
			{
				RenderCommand.SetDepthStencilTarget(DepthStencil);

				RenderCommand.UnbindRenderTargets();
				RenderCommand.SetRenderTarget(Albedo, 0);
				RenderCommand.SetRenderTarget(Normal, 1);
				RenderCommand.SetRenderTarget(Tangent, 2);
				RenderCommand.SetRenderTarget(Position, 3);
				RenderCommand.SetRenderTarget(Material, 4);

				RenderCommand.BindRenderTargets();
			}

			public void Clear()
			{
				RenderCommand.Clear(_gBuffer.Albedo, .Color | .Depth, .HotPink, 1, 0);
				RenderCommand.Clear(_gBuffer.Normal, .HotPink);
				RenderCommand.Clear(_gBuffer.Tangent, .HotPink);
				RenderCommand.Clear(_gBuffer.Position, .HotPink);
				RenderCommand.Clear(_gBuffer.Material, .HotPink);
			}
		}

		static internal GraphicsContext _context;

		//static Buffer<SceneConstants> _sceneConstants ~ _?.ReleaseRef();

		//static Buffer<ObjectConstants> _objectConstants ~ _?.ReleaseRef();

		static SceneConstants _sceneConstants;

		static Effect LineEffect;
		static VertexBuffer LineVertices;
		static GeometryBinding LineGeometry;


		static GeometryBinding s_fullscreenQuadGeometry;

		static GBuffer _gBuffer;
		static Effect TestFullscreenEffect;
		static Effect s_tonemappingEffect;

		static BlendState _gBufferBlend;
		static BlendState _lightBlend;
		static DepthStencilState _fullscreenDepthState;

		public static void Init(GraphicsContext context, EffectLibrary effectLibrary)
		{
			Debug.Profiler.ProfileFunction!();

			_context = context..AddRef();
			/*
			_sceneConstants = new Buffer<SceneConstants>(.(0, .Constant, .Dynamic, .Write));
			_sceneConstants.Update();

			_objectConstants = new Buffer<ObjectConstants>(.(0, .Constant, .Dynamic, .Write));
			_objectConstants.Update();
			*/

			RenderCommand.Init();
			Renderer2D.Init();

			InitLineRenderer(effectLibrary);
			InitDeferredRenderer(effectLibrary);
		}

		public static void Deinit()
		{
			Debug.Profiler.ProfileFunction!();

			DeinitDeferredRenderer();

			DeinitLineRenderer();

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
			VertexLayout layout = new VertexLayout(vertexElements, true, LineEffect.VertexShader);
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

			s_fullscreenQuadGeometry = new GeometryBinding();
			s_fullscreenQuadGeometry.SetPrimitiveTopology(.TriangleList);

			using(var quadVertices = new VertexBuffer(typeof(Vector4), 4, .Immutable))
			{
				Vector4[4] vertices = .(
					.(-1,-1, 0, 1),
					.(-1, 1, 0, 0),
					.( 1, 1, 1, 0),
					.( 1,-1, 1, 1)
					);

				quadVertices.SetData(vertices);
				s_fullscreenQuadGeometry.SetVertexBufferSlot(quadVertices, 0);
			}

			using(var quadIndices = new IndexBuffer(6, .Immutable))
			{
				uint16[6] indices = .(
						0, 1, 2,
						2, 3, 0
					);

				quadIndices.SetData(indices);
				s_fullscreenQuadGeometry.SetIndexBuffer(quadIndices);
			}

			VertexElement[] vertexElements = new .(
				VertexElement(.R32G32_Float, "POSITION"),
				VertexElement(.R32G32_Float, "TEXCOORD")
			);

			using (var quadBatchLayout = new VertexLayout(vertexElements, true, TestFullscreenEffect.VertexShader))
			{
				s_fullscreenQuadGeometry.SetVertexLayout(quadBatchLayout);
			}
			
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
		}

		static void DeinitDeferredRenderer()
		{
			_fullscreenDepthState.ReleaseRef();
			_lightBlend.ReleaseRef();
			_gBufferBlend.ReleaseRef();
			delete _gBuffer;
			s_fullscreenQuadGeometry.ReleaseRef();

			s_tonemappingEffect.ReleaseRef();
			TestFullscreenEffect.ReleaseRef();
		}

		public static void BeginScene(OldCamera camera)
		{
			Debug.Profiler.ProfileRendererFunction!();

			_sceneConstants.ViewProjection = camera.ViewProjection;
			//_sceneConstants.Data.ViewProjection = camera.ViewProjection;
			//_sceneConstants.Update();
		}

		public static void BeginScene(Camera camera, Matrix transform, RenderTarget2D renderTarget, RenderTarget2D finalTarget)
		{
			Debug.Profiler.ProfileRendererFunction!();
			
			Matrix viewProjection = camera.Projection * Matrix.Invert(transform);
			_sceneConstants.ViewProjection = viewProjection;
			_sceneConstants.CameraPosition = transform.Translation;
			_sceneConstants.CameraTarget = renderTarget;
			_sceneConstants.CompositionTarget = finalTarget;
		}

		public static void BeginScene(EditorCamera camera, RenderTarget2D finalTarget)
		{
			Debug.Profiler.ProfileRendererFunction!();
			
			Matrix viewProjection = camera.Projection * camera.View;
			_sceneConstants.ViewProjection = viewProjection;
			_sceneConstants.CameraPosition = camera.Position;
			_sceneConstants.CameraTarget = camera.RenderTarget;
			_sceneConstants.CompositionTarget = finalTarget;
		}

		public static int SortMeshes(SubmittedMesh left, SubmittedMesh right)
		{
			// TODO: Once Material "inheritance" is ready we could perhaps check how similar materials are (e.g. shared textures/variables/etc...)
			// Similar thing could be done for Meshes. Both would probably require a different way to sort howerver?...

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

					// Whether or not the values are squared doesn't affect the order (because square(-root) is a monotonic function)
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

						entry.Material.SetVariable("ViewProjection", _sceneConstants.ViewProjection);

						entry.Material.SetVariable("Transform", entry.Transform);

						Matrix3x3 mat = (Matrix3x3)(entry.Transform).Invert().Transpose();
						entry.Material.SetVariable("Transform_InvT", mat);
					}

					entry.Material.Bind(_context);

					entry.Mesh.Bind();
					RenderCommand.DrawIndexed(entry.Mesh);
				}
			}
			
			{
				Debug.Profiler.ProfileRendererScope!("Draw Lights");

				RenderCommand.UnbindRenderTargets();
				RenderCommand.SetRenderTarget(_sceneConstants.CameraTarget, 0, true);
				RenderCommand.BindRenderTargets();

				RenderCommand.Clear(_sceneConstants.CameraTarget, .Black);

				RenderCommand.SetBlendState(_lightBlend);
				RenderCommand.SetDepthStencilState(_fullscreenDepthState);

				// Scaling to make sure that only the part of the gbuffer that we actually used gets rendered into the viewport.
				Vector2 scaling = Vector2(_sceneConstants.CameraTarget.Width, _sceneConstants.CameraTarget.Height) / (Vector2)_gBuffer.Size;

				for (SubmittedLight light in _lights)
				{
					Debug.Profiler.ProfileRendererScope!("Draw Light");

					Vector3 lightDir = -light.Transform.Forward;

					_gBuffer.Albedo.SamplerState = SamplerStateManager.PointClamp;
	
					TestFullscreenEffect.SetTexture("GBuffer_Albedo", _gBuffer.Albedo);
					TestFullscreenEffect.SetTexture("GBuffer_Normal", _gBuffer.Normal);
					TestFullscreenEffect.SetTexture("GBuffer_Tangent", _gBuffer.Tangent);
					TestFullscreenEffect.SetTexture("GBuffer_Position", _gBuffer.Position);
					TestFullscreenEffect.SetTexture("GBuffer_Material", _gBuffer.Material);
		
					TestFullscreenEffect.Variables["LightColor"].SetData(light.Light.Color);
					TestFullscreenEffect.Variables["Illuminance"].SetData(light.Light.Illuminance);
					TestFullscreenEffect.Variables["LightDir"].SetData(lightDir);

					TestFullscreenEffect.Variables["CameraPos"].SetData(_sceneConstants.CameraPosition);

					TestFullscreenEffect.Variables["Scaling"].SetData(scaling);
		
					TestFullscreenEffect.Bind(_context);
		
					s_fullscreenQuadGeometry.Bind();
					RenderCommand.DrawIndexed(s_fullscreenQuadGeometry);
				}

				_lights.Clear();

				RenderCommand.SetBlendState(_gBufferBlend);
				
				RenderCommand.SetRenderTarget(_sceneConstants.CompositionTarget, 0, false);
				RenderCommand.BindRenderTargets();

				// TODO: Postprocessing effects
				s_tonemappingEffect.SetTexture("CameraTarget", _sceneConstants.CameraTarget);
				s_tonemappingEffect.Bind(_context);
				RenderCommand.DrawIndexed(s_fullscreenQuadGeometry);

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

			public this(GeometryBinding mesh, Material material, Matrix transform)
			{
				Mesh = mesh..AddRef();
				Material = material..AddRef();
				Transform = transform;
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

			_queue.Add(SubmittedMesh(geometry, material, transform));
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
			DrawLine(Vector4(start, 1.0f), Vector4(end, 1.0f), color, .Identity);
		}
		
		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		 * @param transform A transform matrix transforming the line.
		 */
		public static void DrawLine(Vector3 start, Vector3 end, Color color, Matrix transform)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(end, 1.0f), color, transform);
		}
		
		/** @brief Draws a ray.
		 * @param start The start point of the ray.
		 * @param direction The direction of the ray.
		 * @param color The color of the ray.
		 */
		public static void DrawRay(Vector3 start, Vector3 direction, Color color)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(direction, 0.0f), color, .Identity);
		}

		/** @brief Draws a ray.
		 * @param start The start point of the ray.
		 * @param direction The direction of the ray.
		 * @param color The color of the ray.
		 * @param transform A transform matrix transforming the ray.
		 */
		public static void DrawRay(Vector3 start, Vector3 direction, Color color, Matrix transform)
		{
			DrawLine(Vector4(start, 1.0f), Vector4(direction, 0.0f), color, transform);
		}
		
		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		 * @param transform A transform matrix transforming the line.
		 */
		public static void DrawLine(Vector4 start, Vector4 end, Color color, Matrix transform)
		{
			Debug.Profiler.ProfileRendererFunction!();

			LineVertices.SetData(Vector4[2](start, end), 0, .WriteDiscard);
			LineEffect.Variables["ViewProjection"].SetData(_sceneConstants.ViewProjection * transform);
			LineEffect.Variables["Color"].SetData(color);

			LineEffect.Bind(_context);

			LineGeometry.Bind();
			RenderCommand.DrawIndexed(LineGeometry);
		}
	}
}

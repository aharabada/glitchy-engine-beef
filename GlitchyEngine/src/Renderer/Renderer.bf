using GlitchyEngine.Math;
using GlitchyEngine.World;
using System.Collections;
using System;
using GlitchyEngine.Content;

namespace GlitchyEngine.Renderer
{
	public class Renderer
	{
		struct SceneConstants
		{
			public Matrix ViewProjection;
			public float3 CameraPosition;
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

			public uint2 Size => .(_width, _height);

			public RenderTargetGroup Target ~ _?.ReleaseRef();

			public void EnsureSize(uint32 width, uint32 height)
			{
				if (width <= _width && height <= _height)
					return;

				if (_width == 0 || _height == 0)
				{
					SamplerStateDescription samplerDesc = .();
					samplerDesc.MinFilter = .Point;
					samplerDesc.MagFilter = .Point;

					RenderTargetGroupDescription targetDesc = .(width, height,
						TargetDescription[](
							// RGB: Albedo A: Transparency
							.(RenderTargetFormat.R8G8B8A8_UNorm, ownDebugName: new String("RGB: Albedo A: Alpha")){SamplerDescription = samplerDesc},
							// RG: TextureNormal.XY | BA: GeoNrm.XY
							.(RenderTargetFormat.R16G16B16A16_SNorm, ownDebugName: new String("RG: TextureNormal.XY | BA: GeoNrm.XY")){SamplerDescription = samplerDesc},
							// R: GeoNrm.Z | GBA: GeoTan.XYZ
							.(RenderTargetFormat.R16G16B16A16_SNorm, ownDebugName: new String("R: GeoNrm.Z | GBA: GeoTan.XYZ")){SamplerDescription = samplerDesc},
							// RGB: world position XYZ | A: 1.0
							.(RenderTargetFormat.R32G32B32A32_Float, ownDebugName: new String("RGB: world position XYZ | A: 1.0")){SamplerDescription = samplerDesc},
							// RGB: emissive light and color | A: unused
							.(RenderTargetFormat.R16G16B16A16_Float, ownDebugName: new String("RGB: emissive light and color | A: unused")){SamplerDescription = samplerDesc},
							// R: Metallicity | G: Roughness | B: Ambient | A: Unused
							.(RenderTargetFormat.R8G8B8A8_UNorm, ownDebugName: new String("R: Metallicity | G: Roughness | B: Ambient | A: Unused")){SamplerDescription = samplerDesc},
							// EntityId : Needed for editor picking. Simply pass through the EntityId.
							.(RenderTargetFormat.R32_UInt, ownDebugName: new String("EntityId")){SamplerDescription = samplerDesc, ClearColor = .UInt(uint32.MaxValue)},
						),
						TargetDescription(.D24_UNorm_S8_UInt, ownDebugName: new String("DepthStencil")){
							SamplerDescription = samplerDesc,
							// We use an inverted depth buffer so 0.0 represents the furthest distance
							ClearColor = .DepthStencil(0.0f, 0)
						});
					Target = new RenderTargetGroup(targetDesc);
					// TODO: there needs to be a proper way to do it
					Target.[Friend]Identifier = "GBuffer";
					Content.ManageAsset(Target, null);
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

		static SceneConstants _sceneConstants;

		//static AssetHandle<Effect> LineEffect;
		static VertexBuffer LineVertices;
		static GeometryBinding LineGeometry;

		static GBuffer _gBuffer;
		static AssetHandle<Effect> TestFullscreenEffect;
		static AssetHandle<Effect> s_tonemappingEffect;

		static BlendState _gBufferBlend;
		static BlendState _lightBlend;
		/// Depth Stencil State used to render objects.
		static DepthStencilState _meshDepthStencilState;
		/// Depth Stencil State used to render lights and other full screen effects.
		static DepthStencilState _fullscreenDepthState;

		static Buffer _sceneBuffer;
		static Buffer _objectBuffer;

		[Ordered, CRepr]
		struct ObjectConstantsBuffer
		{
			public Matrix Transform;
			public Matrix4x3 Transform_InvT;
			
			public uint32 EntityId;
			private float3 _padding;
		}

		public static void Init()
		{
			Debug.Profiler.ProfileFunction!();

			RenderCommand.Init();
			Renderer2D.Init();
			FullscreenQuad.Init();
			Quad.Init();

			InitLineRenderer();
			InitDeferredRenderer();
		}

		public static void Deinit()
		{
			Debug.Profiler.ProfileFunction!();

			DeinitDeferredRenderer();

			DeinitLineRenderer();
			
			FullscreenQuad.Deinit();
			Renderer2D.Deinit();
			Quad.Deinit();
		}

		static void InitLineRenderer()
		{
			Debug.Profiler.ProfileFunction!();

			//LineEffect = Content.LoadAsset("Shaders\\lineShader.hlsl");

			LineGeometry = new GeometryBinding();
			LineGeometry.SetPrimitiveTopology(.LineList);
			
			float4[2] vertices = .(.Zero, .Zero);
			LineVertices = new VertexBuffer(sizeof(float4), 2, .Dynamic, .Write);
			LineVertices.SetData<float4>(vertices, 0, .WriteDiscard);
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
		}

		static void InitDeferredRenderer()
		{
			TestFullscreenEffect = Content.LoadAsset("Resources/Shaders/simpleLight.hlsl", null, true);
			s_tonemappingEffect = Content.LoadAsset("Resources/Shaders/SimpleTonemapping.hlsl", null, true);

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
			
			DepthStencilStateDescription meshDsDesc = .Default;
			// We use an inverted depth buffer so greater depth values are closer
			meshDsDesc.DepthFunction = .Greater;
			_meshDepthStencilState = new DepthStencilState(meshDsDesc);

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
			_meshDepthStencilState.ReleaseRef();
			_lightBlend.ReleaseRef();
			_gBufferBlend.ReleaseRef();
			delete _gBuffer;
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

			_sceneBuffer.SetData<Matrix>(viewProjection , 0, .WriteDiscard);
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
					float distLeftSq = distanceSq(_sceneConstants.CameraPosition, left.Transform.Translation);
					float distRightSq = distanceSq(_sceneConstants.CameraPosition, right.Transform.Translation);

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
				RenderCommand.SetDepthStencilState(_meshDepthStencilState);

				for (SubmittedMesh entry in _queue)
				{
					Debug.Profiler.ProfileRendererScope!("Draw Mesh");

					{
						Debug.Profiler.ProfileRendererScope!("Update object buffer");

						ObjectConstantsBuffer objectData = ?;
						objectData.Transform = entry.Transform;

						Matrix4x3 mat = Matrix4x3((Matrix3x3)(entry.Transform).Invert().Transpose());
						objectData.Transform_InvT = mat;

						objectData.EntityId = entry.EntityId;

						_objectBuffer.SetData(objectData, 0, .WriteDiscard);
					}

					entry.Material.Bind();
					
					RenderCommand.BindConstantBuffer(_sceneBuffer, 0, .All);
					RenderCommand.BindConstantBuffer(_objectBuffer, 1, .All);

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
				float2 scaling = float2(_sceneConstants.CameraTarget.Width, _sceneConstants.CameraTarget.Height) / (float2)_gBuffer.Size;

				for (SubmittedLight light in _lights)
				{
					Debug.Profiler.ProfileRendererScope!("Draw Light");

					Effect fsEffect = TestFullscreenEffect.Get();

					if (fsEffect == null)
						continue;

					float3 lightDir = -light.Transform.Forward;

					fsEffect.SetTexture("GBuffer_Albedo", _gBuffer.Target, 0);
					fsEffect.SetTexture("GBuffer_Normal", _gBuffer.Target, 1);
					fsEffect.SetTexture("GBuffer_Tangent", _gBuffer.Target, 2);
					fsEffect.SetTexture("GBuffer_Position", _gBuffer.Target, 3);
					fsEffect.SetTexture("GBuffer_Emissive", _gBuffer.Target, 4);
					fsEffect.SetTexture("GBuffer_Material", _gBuffer.Target, 5);
		
					fsEffect.Variables["LightColor"].SetData(light.Light.Color);
					fsEffect.Variables["Illuminance"].SetData(light.Light.Illuminance);
					fsEffect.Variables["LightDir"].SetData(lightDir);

					fsEffect.Variables["CameraPos"].SetData(_sceneConstants.CameraPosition);

					fsEffect.Variables["Scaling"].SetData(scaling);
		
					fsEffect.ApplyChanges();
					fsEffect.Bind();
					
					//RenderCommand.BindEffect(TestFullscreenEffect);

					FullscreenQuad.Draw();
				}

				_lights.Clear();

				// TODO: I don't understand why we need to clear depth here. It should happen in SceneRenderer, but doesn't work for some reason...
				RenderCommand.Clear(_sceneConstants.CompositionTarget, .Depth);

				// Copy EntityIDs to compositionTarget
				_gBuffer.Target.CopyTo(_sceneConstants.CompositionTarget, 1, int2.Zero, int2((int32)_sceneConstants.CameraTarget.Width, (int32)_sceneConstants.CameraTarget.Height), int2.Zero, 6);

				RenderCommand.SetBlendState(_gBufferBlend);

				RenderCommand.UnbindRenderTargets();
				RenderCommand.BindRenderTargets();
				RenderCommand.SetRenderTargetGroup(_sceneConstants.CompositionTarget, true);

				Effect toneMappingFx = s_tonemappingEffect.Get();
				if (toneMappingFx != null)
				{
					// TODO: Postprocessing effects
					toneMappingFx.SetTexture("CameraTarget", _sceneConstants.CameraTarget, 0);
					toneMappingFx.ApplyChanges();
					toneMappingFx.Bind();
	
					RenderCommand.BindRenderTargets();
	
					FullscreenQuad.Draw();
	
					RenderCommand.UnbindTextures();
				}
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
			
			effect.ApplyChanges();
			effect.Bind();

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

			if (geometry == null || material == null)
				return;

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
		public static void DrawLine(float3 start, float3 end, ColorRGBA color)
		{
			Renderer2D.DrawLine(start, end, color);
			//DrawLine(float4(start, 1.0f), float4(end, 1.0f), (ColorRGBA)color, .Identity);
		}
		
		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		 * @param transform A transform matrix transforming the line.
		 */
		public static void DrawLine(float3 start, float3 end, ColorRGBA color, Matrix transform)
		{
			Renderer2D.DrawLine(transform * float4(start, 1.0f), transform * float4(end, 1.0f), color);
		}
		
		/** @brief Draws a ray.
		 * @param start The start point of the ray.
		 * @param direction The direction of the ray.
		 * @param color The color of the ray.
		 */
		public static void DrawRay(float3 start, float3 direction, ColorRGBA color)
		{
			Renderer2D.DrawRay(start, direction, color);
		}

		/** @brief Draws a ray.
		 * @param start The start point of the ray.
		 * @param direction The direction of the ray.
		 * @param color The color of the ray.
		 * @param transform A transform matrix transforming the ray.
		 */
		public static void DrawRay(float3 start, float3 direction, ColorRGBA color, Matrix transform)
		{
			Renderer2D.DrawLine(transform * float4(start, 1.0f), transform * float4(direction, 0.0f), color);
		}
	}
}

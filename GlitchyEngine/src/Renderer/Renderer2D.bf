using GlitchyEngine.Math;
using System.Collections;
using System;
using System.Diagnostics;
using GlitchyEngine.Renderer.Text;
using GlitchyEngine.World;
using GlitchyEngine.Content;

namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	public static class Renderer2D
	{
		[CRepr]
		struct QuadVertex : IVertexData
		{
			public float2 Position;
			public float2 Texcoord;

			public this(float2 position, float2 texcoord)
			{
				Position = position;
				Texcoord = texcoord;
			}

			public this(float x, float y, float texX, float texY)
			{
				Position = .(x, y);
				Texcoord = .(texX, texY);
			}

			public static VertexElement[] VertexElements ~ delete _;

			public static VertexElement[] IVertexData.VertexElements => VertexElements;

			static this()
			{
				VertexElements = new VertexElement[]
				(
					VertexElement(.R32G32_Float, "POSITION"),
					VertexElement(.R32G32_Float, "TEXCOORD"),
				);
			}
		}

		[CRepr]
		struct LineBatchVertex
		{
			public float4 Position;
			public ColorRGBA Color;

			public uint32 EntityId;

			public this(float4 position, ColorRGBA color, uint32 entityId)
			{
				Position = position;
				Color = color;
				EntityId = entityId;
			}
		}
		
		[CRepr]
		struct QuadBatchVertex
		{
			public Matrix Transform;
			public ColorRGBA Color;
			public float4 UVTransform;

			public uint32 EntityId;

			public this(Matrix transform, ColorRGBA color, float4 uvTransform, uint32 entityId)
			{
				Transform = transform;
				Color = color;
				UVTransform = uvTransform;
				EntityId = entityId;
			}
		}
		
		[CRepr]
		struct CircleBatchVertex : QuadBatchVertex
		{
			public float InnerRadius;

			public this(Matrix transform, ColorRGBA color, float4 uvTransform, float innerRadius, uint32 entityId)
				 : base(transform, color, uvTransform, entityId)
			{
				InnerRadius = innerRadius;
			}
		}
		
		enum DrawOrder
		{
			/// Immediately draw the sprites.
			Immediate,
			/**
			 * Deferres rendering until the call of End().
			 * Sorts the sprites by their texture.
			 */
			SortByTexture,
			/**
			 * Deferres rendering until the call of End().
			 * Sorts the sprites so that the backmost will be drawn first and the frontmost last.
			 */
			BackToFront,
			/**
			 * Deferres rendering until the call of End().
			 * Sorts the sprites so that the frontmost will be drawn first and the backmost last.
			 */
			FrontToBack
		}
		
		struct QueueLine: this(float4 Start, float4 End, ColorRGBA Color, float Depth, uint32 entityId = uint32.MaxValue) { }

		struct QueueQuad: this(Matrix Transform, ColorRGBA Color, Texture Texture, float Depth, float4 uvTransform, uint32 entityId = uint32.MaxValue) { }

		struct QueueCircle : QueueQuad
		{
			public float InnerRadius;

			public this(Matrix Transform, ColorRGBA Color, Texture Texture, float Depth, float4 uvTransform, float innerRadius, uint32 entityId = uint32.MaxValue)
				 : base(Transform, Color, Texture, Depth, uvTransform, entityId)
			{
				InnerRadius = innerRadius;
			}
		}

#if DEBUG
		private static bool s_initialized;
		private static bool s_sceneRunning;
#endif

		private static AssetHandle<Effect> s_quadBatchEffect;
		private static AssetHandle<Effect> s_circleBatchEffect;
		private static AssetHandle<Effect> s_lineBatchEffect;
		
		private static GeometryBinding s_quadGeometry;

		private static Texture2D s_whiteTexture;

		private static GeometryBinding s_quadBatchBinding;
		private static GeometryBinding s_circleBatchBinding;
		private static GeometryBinding s_lineBatchBinding;
		private static VertexBuffer s_quadInstanceBuffer;
		private static VertexBuffer s_circleInstanceBuffer;
		private static VertexBuffer s_lineInstanceBuffer;
		
		private static uint32 s_maxInstancesPerBatch = 8192;

		private static QuadBatchVertex[] s_rawQuadInstances;
		private static CircleBatchVertex[] s_rawCircleInstances;
		private static LineBatchVertex[] s_rawLineVertices;
		private static uint32 s_setQuadInstances = 0;
		private static uint32 s_setCircleInstances = 0;
		private static uint32 s_setLineInstances = 0;

		private static List<QueueQuad> s_QuadinstanceQueue;
		private static List<QueueCircle> s_circleInstanceQueue;
		private static List<QueueLine> s_lineInstanceQueue;

		private static DrawOrder s_drawOrder;

		/// The effect that is currently used to draw the sprites.
		private static AssetHandle<Effect> s_currentQuadEffect;
		private static AssetHandle<Effect> s_currentCircleEffect;
		private static AssetHandle<Effect> s_currentLineEffect;

		public static uint32 MaxInstancesPerBatch
		{
			get => s_maxInstancesPerBatch;
			set
			{
				if (s_maxInstancesPerBatch == value)
					return;

				s_maxInstancesPerBatch = value;

				ApplyInstanceCount();
			}
		}
		
		private static void InitEffect()
		{
			Debug.Profiler.ProfileFunction!();

			s_quadBatchEffect = Content.LoadAsset("Resources/Shaders/spritebatch.hlsl", null, true);
			s_circleBatchEffect = Content.LoadAsset("Resources/Shaders/circlebatch.hlsl", null, true);
			s_lineBatchEffect = Content.LoadAsset("Resources/Shaders/linebatch.hlsl", null, true);
		}

		private static void InitGeometry()
		{
			Debug.Profiler.ProfileFunction!();

			s_quadGeometry = new GeometryBinding();
			s_quadGeometry.SetPrimitiveTopology(.TriangleList);

			using(var quadVertices = new VertexBuffer(typeof(QuadVertex), 4, .Immutable))
			{
				QuadVertex[4] vertices = .(
					.(-0.5f,-0.5f, 0, 1),
					.(-0.5f, 0.5f, 0, 0),
					.( 0.5f, 0.5f, 1, 0),
					.( 0.5f,-0.5f, 1, 1)
					);

				quadVertices.SetData(vertices);
				s_quadGeometry.SetVertexBufferSlot(quadVertices, 0);
			}

			using(var quadIndices = new IndexBuffer(6, .Immutable))
			{
				uint16[6] indices = .(
						0, 1, 2,
						2, 3, 0
					);
				
				quadIndices.SetData(indices);
				s_quadGeometry.SetIndexBuffer(quadIndices);
			}
		}

		private static void InitInstancingGeometry()
		{
			Debug.Profiler.ProfileFunction!();

			// Quad
			{
				VertexElement[] vertexElements = new .(
					VertexElement(.R32G32_Float, "POSITION", false, 0, 0, 0, .PerVertexData, 0),
					VertexElement(.R32G32_Float, "TEXCOORD", false, 0, 0, (.)-1, .PerVertexData, 0),
					
					VertexElement(.R32G32B32A32_Float, "TRANSFORM", false, 0, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32G32B32A32_Float, "TRANSFORM", false, 1, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32G32B32A32_Float, "TRANSFORM", false, 2, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32G32B32A32_Float, "TRANSFORM", false, 3, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32G32B32A32_Float,     "COLOR", false, 0, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32G32B32A32_Float,  "TEXCOORD", false, 1, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32_UInt,            "ENTITYID", false, 0, 1, (.)-1, .PerInstanceData, 1)
				);
	
				s_quadBatchBinding = new GeometryBinding();
				s_quadBatchBinding.SetPrimitiveTopology(.TriangleList);

				using (var quadBatchLayout = new VertexLayout(vertexElements, true))
				{
					s_quadBatchBinding.SetVertexLayout(quadBatchLayout);
				}
	
				s_quadBatchBinding.SetVertexBufferSlot(s_quadGeometry.GetVertexBuffer(0), 0);
				s_quadBatchBinding.SetIndexBuffer(s_quadGeometry.GetIndexBuffer(), 0);
			}
			
			// Circle
			{
				VertexElement[] vertexElements = new .(
					VertexElement(.R32G32_Float, "POSITION", false, 0, 0, 0, .PerVertexData, 0),
					VertexElement(.R32G32_Float, "TEXCOORD", false, 0, 0, (.)-1, .PerVertexData, 0),
					
					VertexElement(.R32G32B32A32_Float, "TRANSFORM", false, 0, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32G32B32A32_Float, "TRANSFORM", false, 1, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32G32B32A32_Float, "TRANSFORM", false, 2, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32G32B32A32_Float, "TRANSFORM", false, 3, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32G32B32A32_Float,     "COLOR", false, 0, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32G32B32A32_Float,  "TEXCOORD", false, 1, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32_UInt,  			"ENTITYID", false, 0, 1, (.)-1, .PerInstanceData, 1),
					VertexElement(.R32_Float,  			"TEXCOORD", false, 2, 1, (.)-1, .PerInstanceData, 1)
				);
				
				s_circleBatchBinding = new GeometryBinding();
				s_circleBatchBinding.SetPrimitiveTopology(.TriangleList);

				using (var circleBatchLayout = new VertexLayout(vertexElements, true))
				{
					s_circleBatchBinding.SetVertexLayout(circleBatchLayout);
				}
	
				s_circleBatchBinding.SetVertexBufferSlot(s_quadGeometry.GetVertexBuffer(0), 0);
				s_circleBatchBinding.SetIndexBuffer(s_quadGeometry.GetIndexBuffer(), 0);
			}

			// Line
			{
				VertexElement[] vertexElements = new .(
					VertexElement(.R32G32B32A32_Float, "POSITION", false, 0, 0,     0, .PerVertexData, 0),
					VertexElement(.R32G32B32A32_Float,    "COLOR", false, 0, 0, (.)-1, .PerVertexData, 0),
					VertexElement(.R32_UInt,           "ENTITYID", false, 0, 0, (.)-1, .PerVertexData, 0)
				);

				s_lineBatchBinding = new GeometryBinding();
				s_lineBatchBinding.SetPrimitiveTopology(.LineList);

				using (var lineBatchLayout = new VertexLayout(vertexElements, true))
				{
					s_lineBatchBinding.SetVertexLayout(lineBatchLayout);
				}
			}

			ApplyInstanceCount();
		}

		/// Updates the instance buffers so that they can fit s_maxInstancesPerBatch many instances
		private static void ApplyInstanceCount()
		{
			Debug.Profiler.ProfileFunction!();

			// Quads
			{
				VertexBuffer quadInstanceBuffer = new VertexBuffer(typeof(QuadBatchVertex), s_maxInstancesPerBatch, .Dynamic, .Write);
				quadInstanceBuffer.SetData(0);

				s_quadInstanceBuffer?.ReleaseRef();
				s_quadInstanceBuffer = quadInstanceBuffer;
				s_quadBatchBinding.SetVertexBufferSlot(s_quadInstanceBuffer, 1);

				delete s_rawQuadInstances;
				delete s_QuadinstanceQueue;
				s_rawQuadInstances = new QuadBatchVertex[s_maxInstancesPerBatch];
				s_QuadinstanceQueue = new List<QueueQuad>(s_maxInstancesPerBatch);

			}

			// Circles
			{
				VertexBuffer circleInstanceBuffer = new VertexBuffer(typeof(CircleBatchVertex), s_maxInstancesPerBatch, .Dynamic, .Write);
				circleInstanceBuffer.SetData(0);
				
				s_circleInstanceBuffer?.ReleaseRef();
				s_circleInstanceBuffer = circleInstanceBuffer;
				s_circleBatchBinding.SetVertexBufferSlot(s_circleInstanceBuffer, 1);
				
				delete s_rawCircleInstances;
				delete s_circleInstanceQueue;
				s_rawCircleInstances = new CircleBatchVertex[s_maxInstancesPerBatch];
				s_circleInstanceQueue = new List<QueueCircle>(s_maxInstancesPerBatch);
			}

			// Lines
			{
				VertexBuffer lineInstanceBuffer = new VertexBuffer(typeof(LineBatchVertex), s_maxInstancesPerBatch, .Dynamic, .Write);
				lineInstanceBuffer.SetData(0);
				
				s_lineInstanceBuffer?.ReleaseRef();
				s_lineInstanceBuffer = lineInstanceBuffer;
				s_lineBatchBinding.SetVertexBufferSlot(s_lineInstanceBuffer, 0);
				
				delete s_rawLineVertices;
				delete s_lineInstanceQueue;
				s_rawLineVertices = new LineBatchVertex[s_maxInstancesPerBatch];
				s_lineInstanceQueue = new List<QueueLine>(s_maxInstancesPerBatch);
			}
		}

		private static void InitWhitetexture()
		{
			Debug.Profiler.ProfileFunction!();

			// Create a texture with a single white pixel
			Texture2DDesc tex2Ddesc = .{
				Format = .R8G8B8A8_UNorm,
				Width = 1,
				Height = 1,
				MipLevels = 1,
				ArraySize = 1,
				Usage = .Immutable,
				CpuAccess = .None
			};
			s_whiteTexture = new Texture2D(tex2Ddesc);

			Color color = .White;

			TextureSliceData[1] data = .(.(&color, sizeof(Color), sizeof(Color)));
			s_whiteTexture.SetData(data);

			// Create the default sampler for the white texture
			SamplerState sampler = SamplerStateManager.GetSampler(SamplerStateDescription());
			s_whiteTexture.SamplerState = sampler;

			sampler.ReleaseRef();
		}

		private static BlendState s_opaqueBlendState;
		private static BlendState s_transparentBlendState;
		
		private static void InitStates()
		{
			s_opaqueBlendState = new BlendState(.Default);

			// TODO: alpha is a bitch.
			// This is for premultiplied alpha!!!! However the engine has basically no support for that >:[
			BlendStateDescription transparentDesc = .Default;
			transparentDesc.IndependentBlendEnable = true;
			transparentDesc.RenderTarget[0] = .(true,
				.One, .InvertedSourceAlpha, .Add,
				.One, .One, .Add, .All);

			s_transparentBlendState = new BlendState(transparentDesc);
		}

		public static void Init()
		{
			Debug.Profiler.ProfileFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(!s_initialized, "Renderer2D is already initialized.");
#endif

			InitStates();

			InitEffect();
			InitGeometry();
			InitInstancingGeometry();
			InitWhitetexture();

			FontRenderer.Init();

#if DEBUG
			s_initialized = true;
#endif
		}

		public static void Deinit()
		{
			Debug.Profiler.ProfileFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(s_initialized, "Renderer2D is not initialized.");
#endif

			FontRenderer.Deinit();

			s_quadGeometry.ReleaseRef();

			s_whiteTexture.ReleaseRef();
			
			s_quadBatchBinding.ReleaseRef();
			s_circleBatchBinding.ReleaseRef();
			s_lineBatchBinding.ReleaseRef();
			s_quadInstanceBuffer.ReleaseRef();
			s_circleInstanceBuffer.ReleaseRef();
			s_lineInstanceBuffer.ReleaseRef();

			delete s_rawQuadInstances;
			delete s_rawCircleInstances;
			delete s_rawLineVertices;
			delete s_QuadinstanceQueue;
			delete s_circleInstanceQueue;
			delete s_lineInstanceQueue;

			s_opaqueBlendState.ReleaseRef();
			s_transparentBlendState.ReleaseRef();

#if DEBUG
			s_initialized = false;
#endif
		}

		// TODO: remove?
		public static void BeginScene(OldCamera camera, DrawOrder drawOrder = .SortByTexture, AssetHandle<Effect> effect = .Invalid, AssetHandle<Effect> circleEffect = .Invalid)
		{
			Debug.Profiler.ProfileRendererFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(s_initialized, "Renderer2D was not initialized.");
			Log.EngineLogger.AssertDebug(!s_sceneRunning, "You have to call EndScene before you can make another call to BeginScene.");
#endif

			if(effect != .Invalid)
			{
				s_currentQuadEffect = effect;
			}
			else
			{
				s_currentQuadEffect = s_quadBatchEffect;
			}

			if(circleEffect != .Invalid)
			{
				s_currentCircleEffect = circleEffect;
			}
			else
			{
				s_currentCircleEffect = s_circleBatchEffect;
			}

			s_currentLineEffect = s_lineBatchEffect;

			s_currentQuadEffect.Variables["ViewProjection"].SetData(camera.ViewProjection);
			s_currentCircleEffect.Variables["ViewProjection"].SetData(camera.ViewProjection);

			s_drawOrder = drawOrder;
			
#if DEBUG
			s_sceneRunning = true;
#endif
		}

		public static void BeginScene(Camera camera, Matrix transform, DrawOrder drawOrder = .SortByTexture, AssetHandle<Effect> effect = .Invalid, AssetHandle<Effect> circleEffect = .Invalid)
		{
			Debug.Profiler.ProfileRendererFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(s_initialized, "Renderer2D was not initialized.");
			Log.EngineLogger.AssertDebug(!s_sceneRunning, "You have to call EndScene before you can make another call to BeginScene.");
#endif
			
			if(effect != .Invalid)
			{
				s_currentQuadEffect = effect;
			}
			else
			{
				s_currentQuadEffect = s_quadBatchEffect;
			}

			if(circleEffect != .Invalid)
			{
				s_currentCircleEffect = circleEffect;
			}
			else
			{
				s_currentCircleEffect = s_circleBatchEffect;
			}

			s_currentLineEffect = s_lineBatchEffect;

			Matrix viewProjection = camera.Projection * Matrix.Invert(transform);
			
			s_currentQuadEffect.Variables["ViewProjection"].SetData(viewProjection);
			s_currentCircleEffect.Variables["ViewProjection"].SetData(viewProjection);
			s_currentLineEffect.Variables["ViewProjection"].SetData(viewProjection);

			s_drawOrder = drawOrder;
			
#if DEBUG
			s_sceneRunning = true;
#endif
		}

		public static void BeginScene(EditorCamera camera, DrawOrder drawOrder = .SortByTexture, AssetHandle<Effect> effect = .Invalid, AssetHandle<Effect> circleEffect = .Invalid)
		{
			Debug.Profiler.ProfileRendererFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(s_initialized, "Renderer2D was not initialized.");
			Log.EngineLogger.AssertDebug(!s_sceneRunning, "You have to call EndScene before you can make another call to BeginScene.");
#endif

			if(effect != .Invalid)
			{
				s_currentQuadEffect = effect;
			}
			else
			{
				s_currentQuadEffect = s_quadBatchEffect;
			}

			if(circleEffect != .Invalid)
			{
				s_currentCircleEffect = circleEffect;
			}
			else
			{
				s_currentCircleEffect = s_circleBatchEffect;
			}

			s_currentLineEffect = s_lineBatchEffect;

			Matrix viewProjection = camera.Projection * camera.View;
			
			s_currentQuadEffect.Variables["ViewProjection"].SetData(viewProjection);
			s_currentCircleEffect.Variables["ViewProjection"].SetData(viewProjection);
			s_currentLineEffect.Variables["ViewProjection"].SetData(viewProjection);

			s_drawOrder = drawOrder;
			
#if DEBUG
			s_sceneRunning = true;
#endif
		}

		public static void EndScene()
		{
			Debug.Profiler.ProfileRendererFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");
#endif

			Flush();
#if DEBUG
			s_sceneRunning = false;
#endif
		}

		public static void Flush()
		{
			Debug.Profiler.ProfileFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");
#endif

			if(s_drawOrder != .Immediate)
				DrawDeferred();
		}

		/// Adds a quad instance to the instance queue.
		[Inline]
		private static void QueueQuadInstance(Matrix transform, ColorRGBA color, Texture texture, float depth, float4 uvTransform, uint32 id = uint32.MaxValue)
		{
			s_QuadinstanceQueue.Add(QueueQuad(transform, color, texture ?? s_whiteTexture, depth, uvTransform, id));
			s_statistics.QuadCount++;
		}
		
		/// Adds a circle instance to the instance queue.
		[Inline]
		private static void QueueCircleInstance(Matrix transform, ColorRGBA color, Texture2D texture, float depth, float4 uvTransform, float innerRadius, uint32 id = uint32.MaxValue)
		{
			s_circleInstanceQueue.Add(QueueCircle(transform, color, texture ?? s_whiteTexture, depth, uvTransform, innerRadius, id));
			s_statistics.CircleCount++;
		}
			
		/// Adds a line instance to the instance queue.
		[Inline]
		private static void QueueLineInstance(float4 start, float4 end, ColorRGBA color, uint32 id = uint32.MaxValue)
		{
			s_lineInstanceQueue.Add(QueueLine(start, end, color, id));
			s_statistics.LineCount++;
		}

		private static void FlushQuadInstances()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_setQuadInstances == 0)
				return;

			s_quadInstanceBuffer.SetData<QuadBatchVertex>(s_rawQuadInstances.Ptr, s_setQuadInstances, 0, .WriteDiscard);
			
			s_currentQuadEffect.ApplyChanges();
			s_currentQuadEffect.Bind();
			s_quadBatchBinding.InstanceCount = s_setQuadInstances;
			s_quadBatchBinding.Bind();
			RenderCommand.DrawIndexedInstanced(s_quadBatchBinding);

			s_setQuadInstances = 0;

			s_statistics.QuadDrawCalls++;
		}

		private static void FlushCircleInstances()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_setCircleInstances == 0)
				return;

			s_circleInstanceBuffer.SetData<CircleBatchVertex>(s_rawCircleInstances.Ptr, s_setCircleInstances, 0, .WriteDiscard);
			
			s_currentCircleEffect.ApplyChanges();
			s_currentCircleEffect.Bind();
			s_circleBatchBinding.InstanceCount = s_setCircleInstances;
			s_circleBatchBinding.Bind();
			RenderCommand.DrawIndexedInstanced(s_circleBatchBinding);

			s_setCircleInstances = 0;

			s_statistics.CircleDrawCalls++;
		}
		
		private static void FlushLineInstances()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_setLineInstances == 0)
				return;

			s_lineInstanceBuffer.SetData<LineBatchVertex>(s_rawLineVertices.Ptr, s_setLineInstances, 0, .WriteDiscard);
			
			s_currentLineEffect.ApplyChanges();
			s_currentLineEffect.Bind();
			s_lineBatchBinding.VertexCount = (.)s_setLineInstances;
			s_lineBatchBinding.Bind();
			RenderCommand.DrawIndexed(s_lineBatchBinding);

			s_setLineInstances = 0;

			s_statistics.LineDrawCalls++;
		}

		// Quad comparison
		private static int TextureComparison(QueueQuad lhs, QueueQuad rhs)
		{
			return (int)Internal.UnsafeCastToPtr(lhs.Texture) - (int)Internal.UnsafeCastToPtr(rhs.Texture);
		}
		private static int BackToFrontComparison(QueueQuad lhs, QueueQuad rhs)
		{
			return rhs.Depth <=> lhs.Depth;
		}
		private static int FrontToBackComparison(QueueQuad lhs, QueueQuad rhs)
		{
			return lhs.Depth <=> rhs.Depth;
		}
		
		// Circle comparison
		private static int TextureComparison(QueueCircle lhs, QueueCircle rhs)
		{
			return (int)Internal.UnsafeCastToPtr(lhs.Texture) - (int)Internal.UnsafeCastToPtr(rhs.Texture);
		}
		private static int BackToFrontComparison(QueueCircle lhs, QueueCircle rhs)
		{
			return rhs.Depth <=> lhs.Depth;
		}
		private static int FrontToBackComparison(QueueCircle lhs, QueueCircle rhs)
		{
			return lhs.Depth <=> rhs.Depth;
		}

		// Line comparison
		/*private static int TextureComparison(QueueLine lhs, QueueLine rhs)
		{
			return (int)Internal.UnsafeCastToPtr(lhs.Texture) - (int)Internal.UnsafeCastToPtr(rhs.Texture);
		}*/
		private static int BackToFrontComparison(QueueLine lhs, QueueLine rhs)
		{
			return rhs.Depth <=> lhs.Depth;
		}
		private static int FrontToBackComparison(QueueLine lhs, QueueLine rhs)
		{
			return lhs.Depth <=> rhs.Depth;
		}

		private static void SortInstances()
		{
			Debug.Profiler.ProfileRendererFunction!();

			switch(s_drawOrder)
			{
			case .SortByTexture:
				s_QuadinstanceQueue.Sort(scope => TextureComparison);
				s_circleInstanceQueue.Sort(scope => TextureComparison);
				/*Lines cant be sorted by texture*/
				s_lineInstanceQueue.Sort(scope => BackToFrontComparison);
			case .BackToFront:
				s_QuadinstanceQueue.Sort(scope => BackToFrontComparison);
				s_circleInstanceQueue.Sort(scope => BackToFrontComparison);
				s_lineInstanceQueue.Sort(scope => BackToFrontComparison);
			case .FrontToBack:
				s_QuadinstanceQueue.Sort(scope => FrontToBackComparison);
				s_circleInstanceQueue.Sort(scope => FrontToBackComparison);
				s_lineInstanceQueue.Sort(scope => FrontToBackComparison);
			case .Immediate:
			default:
				Log.EngineLogger.Error("Unknown instance draw order.");
			}
		}

		private static void DrawDeferred()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_QuadinstanceQueue.IsEmpty && s_circleInstanceQueue.IsEmpty && s_lineInstanceQueue.IsEmpty)
				return;

			SortInstances();
			
			RenderCommand.SetDepthStencilState(Renderer.[Friend]_meshDepthStencilState);

			DrawDeferredQuads();
			DrawDeferredCircles();
			DrawDeferredLines();

			RenderCommand.SetDepthStencilState(Renderer.[Friend]_fullscreenDepthState);
		}

		private static void DrawDeferredQuads()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_QuadinstanceQueue.IsEmpty)
				return;
			
			// TODO: per object blendstate
			RenderCommand.SetBlendState(s_transparentBlendState);

			Texture texture = s_QuadinstanceQueue[0].Texture;
			s_currentQuadEffect.SetTexture("Texture", texture);

			s_setQuadInstances = 0;

			for(int i < s_QuadinstanceQueue.Count)
			{
				var quad = ref s_QuadinstanceQueue[i];

				// flush every time the texture changes
				if(quad.Texture != texture)
				{
					FlushQuadInstances();

					texture = quad.Texture;
					s_currentQuadEffect.SetTexture("Texture", texture);
				}

				s_rawQuadInstances[s_setQuadInstances++] = .(quad.Transform, quad.Color, quad.uvTransform, quad.entityId);
				
				if(s_setQuadInstances == s_rawQuadInstances.Count)
				{
					FlushQuadInstances();
				}
			}

			FlushQuadInstances();

			s_QuadinstanceQueue.Clear();
		}

		private static void DrawDeferredCircles()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_circleInstanceQueue.IsEmpty)
				return;

			// TODO: per object blendstate
			RenderCommand.SetBlendState(s_transparentBlendState);

			Texture texture = s_circleInstanceQueue[0].Texture;
			s_currentCircleEffect.SetTexture("Texture", texture);

			s_setCircleInstances = 0;

			for(int i < s_circleInstanceQueue.Count)
			{
				var circle = ref s_circleInstanceQueue[i];

				// flush every time the texture changes
				if(circle.Texture != texture)
				{
					FlushCircleInstances();

					texture = circle.Texture;
					s_currentCircleEffect.SetTexture("Texture", texture);
				}

				s_rawCircleInstances[s_setCircleInstances++] = .(circle.Transform, circle.Color, circle.uvTransform, circle.InnerRadius, circle.entityId);
				
				if(s_setCircleInstances == s_rawCircleInstances.Count)
				{
					FlushCircleInstances();
				}
			}

			FlushCircleInstances();

			s_circleInstanceQueue.Clear();
		}

		private static void DrawDeferredLines()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_lineInstanceQueue.IsEmpty)
				return;

			// TODO: per object blendstate
			RenderCommand.SetBlendState(s_transparentBlendState);

			s_setLineInstances = 0;

			for(int i < s_lineInstanceQueue.Count)
			{
				let line = ref s_lineInstanceQueue[i];

				s_rawLineVertices[s_setLineInstances++] = .(line.Start, line.Color, line.entityId);
				s_rawLineVertices[s_setLineInstances++] = .(line.End, line.Color, line.entityId);
				
				if(s_setLineInstances == s_rawLineVertices.Count)
				{
					FlushLineInstances();
				}
			}

			FlushLineInstances();

			s_lineInstanceQueue.Clear();
		}

		/// A specialized function that calculates the 2D transform matrix
		private static Matrix Calculate2DTransform(float3 translation, float2 scale, float rotation)
		{
			float sin = 0.0f;
			float cos = 1.0f;

			if (rotation != 0.0f)
			{
				sin = Math.Sin(rotation);
				cos = Math.Cos(rotation);
			}

			return .(cos * scale.X, -sin * scale.Y, 0, translation.X,
					 sin * scale.X,  cos * scale.Y, 0, translation.Y,
					      0       ,       0       , 1, translation.Z,
					      0       ,       0       , 0, 1);
		}

		// Primitives
		
		/** @brief Draws a line.
		 * @param start The start point of the line.
		 * @param end The end point of the line.
		 * @param color The color of the line.
		 * @param entityId The optional ID of the entity that belongs to this line (for picking).
		 */
		public static void DrawLine(float3 start, float3 end, ColorRGBA color = .White, uint32 entityId = uint32.MaxValue)
		{
			DrawLine(float4(start, 1.0f), float4(end, 1.0f), color, entityId);
		}
		
		/** @brief Draws a ray.
		 * @param start The start point of the ray.
		 * @param direction The direction of the ray.
		 * @param color The color of the ray.
		 * @param entityId The optional ID of the entity that belongs to this ray (for picking).
		 */
		public static void DrawRay(float3 start, float3 direction, ColorRGBA color = .White, uint32 entityId = uint32.MaxValue)
		{
			DrawLine(float4(start, 1.0f), float4(direction, 0.0f), color, entityId);
		}
		
		/** @brief Draws a rectangle.
		 * @param position The center of the rectangle.
		 * @param size The size of the rectangle.
		 * @param color The color of the rectangle.
		 * @param entityId The optional ID of the entity that belongs to this rectangle (for picking).
		 */
		public static void DrawRect(float2 position, float2 size, ColorRGBA color = .White, uint32 entityId = uint32.MaxValue)
		{
			float2 halfSize = size / 2;

			float4 p0 = float4(position + float2(-halfSize.X, -halfSize.Y), 0.0f, 1.0f);
			float4 p1 = float4(position + float2(halfSize.X, -halfSize.Y), 0.0f, 1.0f);
			float4 p2 = float4(position + float2(halfSize.X, halfSize.Y), 0.0f, 1.0f);
			float4 p3 = float4(position + float2(-halfSize.X, halfSize.Y), 0.0f, 1.0f);

			DrawLine(p0, p1, color, entityId);
			DrawLine(p1, p2, color, entityId);
			DrawLine(p2, p3, color, entityId);
			DrawLine(p3, p0, color, entityId);
		}
		
		/** @brief Draws a rectangle.
		 * @param transform The transform of the rectangle.
		 * @param color The color of the rectangle.
		 * @param entityId The optional ID of the entity that belongs to this rectangle (for picking).
		 */
		public static void DrawRect(Matrix transform, ColorRGBA color = .White, uint32 entityId = uint32.MaxValue)
		{
			float2 halfSize = float2.One / 2.0f;

			float4 p0 = transform * float4(-halfSize.X, -halfSize.Y, 0.0f, 1.0f);
			float4 p1 = transform * float4(halfSize.X, -halfSize.Y, 0.0f, 1.0f);
			float4 p2 = transform * float4(halfSize.X, halfSize.Y, 0.0f, 1.0f);
			float4 p3 = transform * float4(-halfSize.X, halfSize.Y, 0.0f, 1.0f);

			DrawLine(p0, p1, color, entityId);
			DrawLine(p1, p2, color, entityId);
			DrawLine(p2, p3, color, entityId);
			DrawLine(p3, p0, color, entityId);
		}

		public static void DrawLine(float4 start, float4 end, ColorRGBA color = .White, uint32 entityId = uint32.MaxValue)
		{
			Debug.Profiler.ProfileRendererFunction!();

#if DEBUG
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");
#endif

			QueueLineInstance(start, end, color, entityId);

			if(s_drawOrder == .Immediate)
			{
				DrawDeferred();
			}
		}

		// Colored Quad

		public static void DrawQuad(float2 position, float2 size, float rotation, ColorRGBA color)
		{
			DrawQuad(float3(position, 0.0f), size, rotation, s_whiteTexture, color);
		}

		/// Like DrawQuad but the pivot point is the top left corner
		public static void DrawQuadPivotCorner(float2 position, float2 size, float rotation, ColorRGBA color)
		{
			DrawQuadPivotCorner(float3(position, 0.0f), size, rotation, s_whiteTexture, color);
		}
		
		public static void DrawQuad(float3 position, float2 size, float rotation, ColorRGBA color)
		{
			DrawQuad(position, size, rotation, s_whiteTexture, color);
		}
		
		public static void DrawQuadPivotCorner(float3 position, float2 size, float rotation, ColorRGBA color)
		{
			DrawQuadPivotCorner(position, size, rotation, s_whiteTexture, color);
		}
		
		public static void DrawQuad(Matrix transform, ColorRGBA color)
		{
			DrawQuad(transform, s_whiteTexture, color);
		}

		// Quad Subtexture

		[Inline]
		private static float4 CalculateSubTexcoords(float4 texCoords, float4 innerTexcoords)
		{
			float4 uv = texCoords;
			uv.XY += innerTexcoords.XY * uv.ZW;
			uv.ZW *= innerTexcoords.ZW;

			return uv;
		}

		// Subtex only

		public static void DrawQuad(float2 position, float2 size, float rotation, SubTexture2D texture, ColorRGBA color = .White)
		{
			DrawQuad(float3(position, 0.0f), size, rotation, texture.Texture, .White, texture.TexCoords);
		}

		public static void DrawQuad(float3 position, float2 size, float rotation, SubTexture2D texture, ColorRGBA color = .White)
		{
			DrawQuad(position, size, rotation, texture.Texture, .White, texture.TexCoords);
		}
		
		public static void DrawQuad(Matrix transform, SubTexture2D texture, ColorRGBA color = .White)
		{
			DrawQuad(transform, texture.Texture, color, texture.TexCoords);
		}

		// Subtex + Texcoords
		
		public static void DrawQuad(float2 position, float2 size, float rotation, SubTexture2D subtexture, ColorRGBA color = .White, float4 uvTransform = .(0, 0, 1, 1))
		{
			float4 uv = CalculateSubTexcoords(subtexture.TexCoords, uvTransform);

			DrawQuad(float3(position, 0.0f), size, rotation, subtexture.Texture, .White, uv);
		}

		public static void DrawQuad(float3 position, float2 size, float rotation, SubTexture2D subtexture, ColorRGBA color = .White, float4 uvTransform = .(0, 0, 1, 1))
		{
			float4 uv = CalculateSubTexcoords(subtexture.TexCoords, uvTransform);

			DrawQuad(position, size, rotation, subtexture.Texture, .White, uv);
		}

		public static void DrawQuad(Matrix transform, SubTexture2D subtexture, ColorRGBA color = .White, float4 uvTransform = .(0, 0, 1, 1), uint32 entityId = uint32.MaxValue)
		{
			float4 uv = CalculateSubTexcoords(subtexture.TexCoords, uvTransform);

			DrawQuad(transform, subtexture.Texture, color, uv, entityId);
		}
		
		// Textured Quad

		public static void DrawQuad(float2 position, float2 size, float rotation, Texture texture, ColorRGBA color = .White, float4 uvTransform = .(0, 0, 1, 1))
		{
			DrawQuad(float3(position, 0.0f), size, rotation, texture, color, uvTransform);
		}

		public static void DrawQuad(float3 position, float2 size, float rotation, Texture texture, ColorRGBA color = .White, float4 uvTransform = .(0, 0, 1, 1))
		{
			Matrix transform = Calculate2DTransform(position, size, rotation);

			DrawQuad(transform, texture, color, uvTransform);
		}

		public static void DrawQuad(Matrix transform, Texture texture, ColorRGBA color = .White, float4 uvTransform = .(0, 0, 1, 1), uint32 entityId = uint32.MaxValue)
		{
			Debug.Profiler.ProfileRendererFunction!();

#if DEBUG
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");
#endif

			QueueQuadInstance(transform, color, texture, transform.Translation.Z, uvTransform, entityId);

			if(s_drawOrder == .Immediate)
			{
				DrawDeferred();
			}
		}

		public static void DrawSprite(Matrix transform, SpriteRendererComponent* spriteRenderer, uint32 entityId)
		{
			DrawQuad(transform, spriteRenderer.Sprite.Get() ?? s_whiteTexture, spriteRenderer.Color, spriteRenderer.UvTransform, entityId);
		}

		public static void DrawCircle(Matrix transform, CircleRendererComponent* spriteRenderer, uint32 entityId)
		{
			DrawCircle(transform, spriteRenderer.Sprite.Get() ?? s_whiteTexture, spriteRenderer.Color, spriteRenderer.InnerRadius, spriteRenderer.UvTransform, entityId);
		}

		// Textured quad pivot

		public static void DrawQuadPivotCorner(float2 position, float2 size, float rotation, Texture2D texture, ColorRGBA color = .White, float4 uvTransform = .(0, 0, 1, 1))
		{
			DrawQuadPivotCorner(float3(position, 0.0f), size, rotation, texture, color, uvTransform);
		}

		public static void DrawQuadPivotCorner(float3 position, float2 size, float rotation, Texture2D texture, ColorRGBA color = .White, float4 uvTransform = .(0, 0, 1, 1))
		{
			DrawQuad(position + float3(size.X / 2, size.Y / -2, 0), size, rotation, texture, color, uvTransform);
		}

		// Circle

		public static void DrawCircle(float2 position, float2 size, ColorRGBA color, float innerRadius = 1.0f)
		{
			DrawCircle(float3(position, 0.0f), size, 0, s_whiteTexture, color, innerRadius);
		}

		public static void DrawCircle(float3 position, float2 size, ColorRGBA color, float innerRadius = 1.0f)
		{
			DrawCircle(position, size, 0, s_whiteTexture, color, innerRadius);
		}

		public static void DrawCircle(float2 position, float2 size, float rotation, Texture2D texture, ColorRGBA color = .White, float innerRadius = 1.0f, float4 uvTransform = .(0, 0, 1, 1))
		{
			DrawCircle(float3(position, 0.0f), size, rotation, texture, color, innerRadius, uvTransform);
		}

		public static void DrawCircle(float3 position, float2 size, float rotation, Texture2D texture, ColorRGBA color = .White, float innerRadius = 1.0f, float4 uvTransform = .(0, 0, 1, 1))
		{
			Matrix transform = Calculate2DTransform(position, size, rotation);

			DrawCircle(transform, texture, color, innerRadius, uvTransform);
		}
		
		public static void DrawCircle(Matrix transform, Texture2D texture, ColorRGBA color = .White, float innerRadius = 1.0f, float4 uvTransform = .(0, 0, 1, 1), uint32 entityId = uint32.MaxValue)
		{
			Debug.Profiler.ProfileRendererFunction!();

#if DEBUG
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");
#endif

			QueueCircleInstance(transform, color, texture, transform.Translation.Z, uvTransform, innerRadius, entityId);

			if(s_drawOrder == .Immediate)
			{
				DrawDeferred();
			}
		}

		public struct Statistics
		{
			public uint32 QuadDrawCalls = 0;
			public uint32 CircleDrawCalls = 0;
			public uint32 LineDrawCalls = 0;

			public uint32 QuadCount = 0;
			public uint32 CircleCount = 0;
			public uint32 LineCount = 0;
			
			public uint32 TotalDrawCalls => QuadDrawCalls + CircleDrawCalls + LineDrawCalls;
			public uint32 TotalInstanceCount => QuadCount + CircleCount + LineCount;
			public uint32 TotalVertexCount => (QuadCount + CircleCount) * 4 + LineCount * 2;
			public uint32 TotalTriangleCount => (QuadCount + CircleCount) * 2;
			public uint32 TotalIndexCount => (QuadCount + CircleCount) * 6;

			public void Reset() mut
			{
				QuadDrawCalls = 0;
				CircleDrawCalls = 0;
				LineDrawCalls = 0;
				QuadCount = 0;
				CircleCount = 0;
				LineCount = 0;
			}
		}

		private static Statistics s_statistics;

		public static ref Statistics Stats => ref s_statistics;
	}
}

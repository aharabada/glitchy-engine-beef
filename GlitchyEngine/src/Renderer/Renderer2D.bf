using GlitchyEngine.Math;
using System.Collections;
using System;
using System.Diagnostics;
using GlitchyEngine.Renderer.Text;
using GlitchyEngine.World;

namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	public static class Renderer2D
	{
		[CRepr]
		struct QuadVertex : IVertexData
		{
			public Vector2 Position;
			public Vector2 Texcoord;

			public this(Vector2 position, Vector2 texcoord)
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
		struct BatchVertex
		{
			public Matrix Transform;
			public ColorRGBA Color;
			public Vector4 UVTransform;

			public this(Matrix transform, ColorRGBA color, Vector4 uvTransform)
			{
				Transform = transform;
				Color = color;
				UVTransform = uvTransform;
			}
		}
		
		[CRepr]
		struct CircleBatchVertex : BatchVertex
		{
			public float InnerRadius;

			public this(Matrix transform, ColorRGBA color, Vector4 uvTransform, float innerRadius)
				 : base(transform, color, uvTransform)
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

		struct QueueQuad: this(Matrix Transform, ColorRGBA Color, Texture Texture, float Depth, Vector4 uvTransform) { }

		struct QueueCircle : QueueQuad
		{
			public float InnerRadius;

			public this(Matrix Transform, ColorRGBA Color, Texture Texture, float Depth, Vector4 uvTransform, float innerRadius)
				 : base(Transform, Color, Texture, Depth, uvTransform)
			{
				InnerRadius = innerRadius;
			}
		}

#if DEBUG
		private static bool s_initialized;
		private static bool s_sceneRunning;
#endif

		private static Effect s_batchEffect;
		private static Effect s_circleBatchEffect;

		private static GeometryBinding s_quadGeometry;

		private static Texture2D s_whiteTexture;

		private static GeometryBinding s_quadBatchBinding;
		private static GeometryBinding s_circleBatchBinding;
		private static VertexBuffer s_quadInstanceBuffer;
		private static VertexBuffer s_circleInstanceBuffer;
		
		private static uint32 s_maxInstancesPerBatch = 8192;

		private static BatchVertex[] s_rawQuadInstances;
		private static CircleBatchVertex[] s_rawCircleInstances;
		private static uint32 s_setInstances = 0;

		private static List<QueueQuad> s_QuadinstanceQueue;
		private static List<QueueCircle> s_circleInstanceQueue;

		private static DrawOrder s_drawOrder;

		/// The effect that is currently used to draw the sprites.
		private static Effect s_currentEffect;
		private static Effect s_currentCircleEffect;

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

			s_batchEffect = new Effect("content\\Shaders\\spritebatch.hlsl");
			s_circleBatchEffect = new Effect("content\\Shaders\\circlebatch.hlsl");
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
					VertexElement(.R32G32B32A32_Float,  "TEXCOORD", false, 1, 1, (.)-1, .PerInstanceData, 1)
				);
	
				s_quadBatchBinding = new GeometryBinding();
				s_quadBatchBinding.SetPrimitiveTopology(.TriangleList);

				using (var quadBatchLayout = new VertexLayout(vertexElements, true, s_batchEffect.VertexShader))
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
					VertexElement(.R32_Float,  			"TEXCOORD", false, 2, 1, (.)-1, .PerInstanceData, 1)
				);
				
				s_circleBatchBinding = new GeometryBinding();
				s_circleBatchBinding.SetPrimitiveTopology(.TriangleList);

				using (var circleBatchLayout = new VertexLayout(vertexElements, true, s_circleBatchEffect.VertexShader))
				{
					s_circleBatchBinding.SetVertexLayout(circleBatchLayout);
				}
	
				s_circleBatchBinding.SetVertexBufferSlot(s_quadGeometry.GetVertexBuffer(0), 0);
				s_circleBatchBinding.SetIndexBuffer(s_quadGeometry.GetIndexBuffer(), 0);
			}

			ApplyInstanceCount();
		}

		/// Updates the instance buffers so that they can fit s_maxInstancesPerBatch many instances
		private static void ApplyInstanceCount()
		{
			Debug.Profiler.ProfileFunction!();

			// Quads
			{
				VertexBuffer quadInstanceBuffer = new VertexBuffer(typeof(BatchVertex), s_maxInstancesPerBatch, .Dynamic, .Write);
				quadInstanceBuffer.SetData(0);

				s_quadInstanceBuffer?.ReleaseRef();
				s_quadInstanceBuffer = quadInstanceBuffer;
				s_quadBatchBinding.SetVertexBufferSlot(s_quadInstanceBuffer, 1);

				delete s_rawQuadInstances;
				delete s_QuadinstanceQueue;
				s_rawQuadInstances = new BatchVertex[s_maxInstancesPerBatch];
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
			s_whiteTexture.SetData(&color);

			// Create the default sampler for the white texture
			SamplerState sampler = SamplerStateManager.GetSampler(SamplerStateDescription());
			s_whiteTexture.SamplerState = sampler;

			sampler.ReleaseRef();
		}

		public static void Init()
		{
			Debug.Profiler.ProfileFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(!s_initialized, "Renderer2D is already initialized.");
#endif

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

			s_batchEffect.ReleaseRef();
			s_circleBatchEffect.ReleaseRef();

			s_quadGeometry.ReleaseRef();

			s_whiteTexture.ReleaseRef();
			
			s_quadBatchBinding.ReleaseRef();
			s_circleBatchBinding.ReleaseRef();
			s_quadInstanceBuffer.ReleaseRef();
			s_circleInstanceBuffer.ReleaseRef();

			delete s_rawQuadInstances;
			delete s_rawCircleInstances;
			delete s_QuadinstanceQueue;
			delete s_circleInstanceQueue;

			s_currentEffect?.ReleaseRef();
			s_currentCircleEffect?.ReleaseRef();

#if DEBUG
			s_initialized = false;
#endif
		}

		// TODO: remove?
		public static void BeginScene(OldCamera camera, DrawOrder drawOrder = .SortByTexture, Effect effect = null, Effect circleEffect = null)
		{
			Debug.Profiler.ProfileRendererFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(s_initialized, "Renderer2D was not initialized.");
			Log.EngineLogger.AssertDebug(!s_sceneRunning, "You have to call EndScene before you can make another call to BeginScene.");
#endif

			//s_textureColorEffect.Bind(Renderer._context);
			
			s_currentEffect?.ReleaseRef();
			if(effect != null)
			{
				s_currentEffect = effect..AddRef();
			}
			else
			{
				s_currentEffect = s_batchEffect..AddRef();
			}

			s_currentCircleEffect?.ReleaseRef();
			if(circleEffect != null)
			{
				s_currentCircleEffect = effect..AddRef();
			}
			else
			{
				s_currentCircleEffect = s_circleBatchEffect..AddRef();
			}
			
			s_currentEffect.Variables["ViewProjection"].SetData(camera.ViewProjection);
			s_currentCircleEffect.Variables["ViewProjection"].SetData(camera.ViewProjection);

			s_drawOrder = drawOrder;
			
#if DEBUG
			s_sceneRunning = true;
#endif
		}

		public static void BeginScene(Camera camera, Matrix transform, DrawOrder drawOrder = .SortByTexture, Effect effect = null, Effect circleEffect = null)
		{
			Debug.Profiler.ProfileRendererFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(s_initialized, "Renderer2D was not initialized.");
			Log.EngineLogger.AssertDebug(!s_sceneRunning, "You have to call EndScene before you can make another call to BeginScene.");
#endif

			//s_textureColorEffect.Bind(Renderer._context);
			
			s_currentEffect?.ReleaseRef();
			if(effect != null)
			{
				s_currentEffect = effect..AddRef();
			}
			else
			{
				s_currentEffect = s_batchEffect..AddRef();
			}

			s_currentCircleEffect?.ReleaseRef();
			if(circleEffect != null)
			{
				s_currentCircleEffect = effect..AddRef();
			}
			else
			{
				s_currentCircleEffect = s_circleBatchEffect..AddRef();
			}

			Matrix viewProjection = camera.Projection * Matrix.Invert(transform);
			
			s_currentEffect.Variables["ViewProjection"].SetData(viewProjection);
			s_currentCircleEffect.Variables["ViewProjection"].SetData(viewProjection);

			s_drawOrder = drawOrder;
			
#if DEBUG
			s_sceneRunning = true;
#endif
		}

		public static void BeginScene(EditorCamera camera, DrawOrder drawOrder = .SortByTexture, Effect effect = null, Effect circleEffect = null)
		{
			Debug.Profiler.ProfileRendererFunction!();
#if DEBUG
			Log.EngineLogger.AssertDebug(s_initialized, "Renderer2D was not initialized.");
			Log.EngineLogger.AssertDebug(!s_sceneRunning, "You have to call EndScene before you can make another call to BeginScene.");
#endif

			//s_textureColorEffect.Bind(Renderer._context);
			
			s_currentEffect?.ReleaseRef();
			if(effect != null)
			{
				s_currentEffect = effect..AddRef();
			}
			else
			{
				s_currentEffect = s_batchEffect..AddRef();
			}

			s_currentCircleEffect?.ReleaseRef();
			if(circleEffect != null)
			{
				s_currentCircleEffect = effect..AddRef();
			}
			else
			{
				s_currentCircleEffect = s_circleBatchEffect..AddRef();
			}

			Matrix viewProjection = camera.Projection * camera.View;
			
			s_currentEffect.Variables["ViewProjection"].SetData(viewProjection);
			s_currentCircleEffect.Variables["ViewProjection"].SetData(viewProjection);

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
		private static void QueueQuadInstance(Matrix transform, ColorRGBA color, Texture texture, float depth, Vector4 uvTransform)
		{
			s_QuadinstanceQueue.Add(QueueQuad(transform, color, texture ?? s_whiteTexture, depth, uvTransform));
			s_statistics.QuadCount++;
		}
		
		/// Adds a circle instance to the instance queue.
		[Inline]
		private static void QueueCircleInstance(Matrix transform, ColorRGBA color, Texture2D texture, float depth, Vector4 uvTransform, float innerRadius)
		{
			s_circleInstanceQueue.Add(QueueCircle(transform, color, texture ?? s_whiteTexture, depth, uvTransform, innerRadius));
			s_statistics.CircleCount++;
		}
		
		private static void FlushInstances()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_setInstances == 0)
				return;

			s_quadInstanceBuffer.SetData<BatchVertex>(s_rawQuadInstances.Ptr, s_setInstances, 0, .WriteDiscard);
			
			s_currentEffect.Bind(Renderer._context);
			s_quadBatchBinding.InstanceCount = s_setInstances;
			s_quadBatchBinding.Bind();
			RenderCommand.DrawIndexedInstanced(s_quadBatchBinding);

			s_setInstances = 0;

			s_statistics.QuadDrawCalls++;
		}

		private static void FlushCircleInstances()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_setInstances == 0)
				return;

			s_circleInstanceBuffer.SetData<CircleBatchVertex>(s_rawCircleInstances.Ptr, s_setInstances, 0, .WriteDiscard);
			
			s_currentCircleEffect.Bind(Renderer._context);
			s_circleBatchBinding.InstanceCount = s_setInstances;
			s_circleBatchBinding.Bind();
			RenderCommand.DrawIndexedInstanced(s_circleBatchBinding);

			s_setInstances = 0;

			s_statistics.CircleDrawCalls++;
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

		private static void SortInstances()
		{
			Debug.Profiler.ProfileRendererFunction!();

			switch(s_drawOrder)
			{
			case .SortByTexture:
				s_QuadinstanceQueue.Sort(scope => TextureComparison);
				s_circleInstanceQueue.Sort(scope => TextureComparison);
			case .BackToFront:
				s_QuadinstanceQueue.Sort(scope => BackToFrontComparison);
				s_circleInstanceQueue.Sort(scope => BackToFrontComparison);
			case .FrontToBack:
				s_QuadinstanceQueue.Sort(scope => FrontToBackComparison);
				s_circleInstanceQueue.Sort(scope => FrontToBackComparison);
			case .Immediate:
			default:
				Log.EngineLogger.Error("Unknown instance draw order.");
			}
		}

		private static void DrawDeferred()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_QuadinstanceQueue.IsEmpty && s_circleInstanceQueue.IsEmpty)
				return;

			SortInstances();

			DrawDeferredQuads();
			DrawDeferredCircles();
		}

		private static void DrawDeferredQuads()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_QuadinstanceQueue.IsEmpty)
				return;

			Texture texture = s_QuadinstanceQueue[0].Texture;
			s_currentEffect.SetTexture("Texture", texture);

			s_setInstances = 0;

			for(int i < s_QuadinstanceQueue.Count)
			{
				var quad = ref s_QuadinstanceQueue[i];

				// flush every time the texture changes
				if(quad.Texture != texture)
				{
					FlushInstances();

					texture = quad.Texture;
					s_currentEffect.SetTexture("Texture", texture);
				}

				s_rawQuadInstances[s_setInstances++] = .(quad.Transform, quad.Color, quad.uvTransform);
				
				if(s_setInstances == s_rawQuadInstances.Count)
				{
					FlushInstances();
				}
			}

			FlushInstances();

			s_QuadinstanceQueue.Clear();
		}

		private static void DrawDeferredCircles()
		{
			Debug.Profiler.ProfileRendererFunction!();

			if(s_circleInstanceQueue.IsEmpty)
				return;

			Texture texture = s_circleInstanceQueue[0].Texture;
			s_currentCircleEffect.SetTexture("Texture", texture);

			s_setInstances = 0;

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

				s_rawCircleInstances[s_setInstances++] = .(circle.Transform, circle.Color, circle.uvTransform, circle.InnerRadius);
				
				if(s_setInstances == s_rawCircleInstances.Count)
				{
					FlushCircleInstances();
				}
			}

			FlushCircleInstances();

			s_circleInstanceQueue.Clear();
		}

		/// A specialized function that calculates the 2D transform matrix
		private static Matrix Calculate2DTransform(Vector3 translation, Vector2 scale, float rotation)
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

		// Colored Quad

		public static void DrawQuad(Vector2 position, Vector2 size, float rotation, ColorRGBA color)
		{
			DrawQuad(Vector3(position, 0.0f), size, rotation, s_whiteTexture, color);
		}

		/// Like DrawQuad but the pivot point is the top left corner
		public static void DrawQuadPivotCorner(Vector2 position, Vector2 size, float rotation, ColorRGBA color)
		{
			DrawQuadPivotCorner(Vector3(position, 0.0f), size, rotation, s_whiteTexture, color);
		}
		
		public static void DrawQuad(Vector3 position, Vector2 size, float rotation, ColorRGBA color)
		{
			DrawQuad(position, size, rotation, s_whiteTexture, color);
		}
		
		public static void DrawQuadPivotCorner(Vector3 position, Vector2 size, float rotation, ColorRGBA color)
		{
			DrawQuadPivotCorner(position, size, rotation, s_whiteTexture, color);
		}
		
		public static void DrawQuad(Matrix transform, ColorRGBA color)
		{
			DrawQuad(transform, s_whiteTexture, color);
		}

		// Quad Subtexture

		[Inline]
		private static Vector4 CalculateSubTexcoords(Vector4 texCoords, Vector4 innerTexcoords)
		{
			Vector4 uv = texCoords;
			uv.XY += innerTexcoords.XY * uv.ZW;
			uv.ZW *= innerTexcoords.ZW;

			return uv;
		}

		// Subtex only

		public static void DrawQuad(Vector2 position, Vector2 size, float rotation, SubTexture2D texture, ColorRGBA color = .White)
		{
			DrawQuad(Vector3(position, 0.0f), size, rotation, texture.Texture, .White, texture.TexCoords);
		}

		public static void DrawQuad(Vector3 position, Vector2 size, float rotation, SubTexture2D texture, ColorRGBA color = .White)
		{
			DrawQuad(position, size, rotation, texture.Texture, .White, texture.TexCoords);
		}
		
		public static void DrawQuad(Matrix transform, SubTexture2D texture, ColorRGBA color = .White)
		{
			DrawQuad(transform, texture.Texture, .White, texture.TexCoords);
		}

		// Subtex + Texcoords
		
		public static void DrawQuad(Vector2 position, Vector2 size, float rotation, SubTexture2D subtexture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			Vector4 uv = CalculateSubTexcoords(subtexture.TexCoords, uvTransform);

			DrawQuad(Vector3(position, 0.0f), size, rotation, subtexture.Texture, .White, uv);
		}

		public static void DrawQuad(Vector3 position, Vector2 size, float rotation, SubTexture2D subtexture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			Vector4 uv = CalculateSubTexcoords(subtexture.TexCoords, uvTransform);

			DrawQuad(position, size, rotation, subtexture.Texture, .White, uv);
		}

		public static void DrawQuad(Matrix transform, SubTexture2D subtexture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			Vector4 uv = CalculateSubTexcoords(subtexture.TexCoords, uvTransform);

			DrawQuad(transform, subtexture.Texture, .White, uv);
		}
		
		// Textured Quad

		public static void DrawQuad(Vector2 position, Vector2 size, float rotation, Texture texture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			DrawQuad(Vector3(position, 0.0f), size, rotation, texture, color, uvTransform);
		}

		public static void DrawQuad(Vector3 position, Vector2 size, float rotation, Texture texture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			Matrix transform = Calculate2DTransform(position, size, rotation);

			DrawQuad(transform, texture, color, uvTransform);
		}

		public static void DrawQuad(Matrix transform, Texture texture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			Debug.Profiler.ProfileRendererFunction!();

#if DEBUG
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");
#endif

			QueueQuadInstance(transform, color, texture, transform.Translation.Z, uvTransform);

			if(s_drawOrder == .Immediate)
			{
				DrawDeferred();
			}
		}

		// Textured quad pivot

		public static void DrawQuadPivotCorner(Vector2 position, Vector2 size, float rotation, Texture2D texture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			DrawQuadPivotCorner(Vector3(position, 0.0f), size, rotation, texture, color, uvTransform);
		}

		public static void DrawQuadPivotCorner(Vector3 position, Vector2 size, float rotation, Texture2D texture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			DrawQuad(position + Vector3(size.X / 2, size.Y / -2, 0), size, rotation, texture, color, uvTransform);
		}

		// Circle

		public static void DrawCircle(Vector2 position, Vector2 size, ColorRGBA color, float innerRadius = 1.0f)
		{
			DrawCircle(Vector3(position, 0.0f), size, 0, s_whiteTexture, color, innerRadius);
		}

		public static void DrawCircle(Vector3 position, Vector2 size, ColorRGBA color, float innerRadius = 1.0f)
		{
			DrawCircle(position, size, 0, s_whiteTexture, color, innerRadius);
		}

		public static void DrawCircle(Vector2 position, Vector2 size, float rotation, Texture2D texture, ColorRGBA color = .White, float innerRadius = 1.0f, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			DrawCircle(Vector3(position, 0.0f), size, rotation, texture, color, innerRadius, uvTransform);
		}

		public static void DrawCircle(Vector3 position, Vector2 size, float rotation, Texture2D texture, ColorRGBA color = .White, float innerRadius = 1.0f, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			Matrix transform = Calculate2DTransform(position, size, rotation);

			DrawCircle(transform, texture, color, innerRadius, uvTransform);
		}
		
		public static void DrawCircle(Matrix transform, Texture2D texture, ColorRGBA color = .White, float innerRadius = 1.0f, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			Debug.Profiler.ProfileRendererFunction!();

#if DEBUG
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");
#endif

			QueueCircleInstance(transform, color, texture, transform.Translation.Z, uvTransform, innerRadius);

			if(s_drawOrder == .Immediate)
			{
				DrawDeferred();
			}
		}

		public struct Statistics
		{
			public uint32 QuadDrawCalls = 0;
			public uint32 CircleDrawCalls = 0;
			public uint32 QuadCount = 0;
			public uint32 CircleCount = 0;
			
			public uint32 TotalDrawCalls => QuadDrawCalls + CircleDrawCalls;
			public uint32 TotalInstanceCount => QuadCount + CircleCount;
			public uint32 TotalVertexCount => TotalInstanceCount * 4;
			public uint32 TotalTriangleCount => TotalInstanceCount * 2;
			public uint32 TotalIndexCount => TotalInstanceCount * 6;

			public void Reset() mut
			{
				QuadDrawCalls = 0;
				CircleDrawCalls = 0;
				QuadCount = 0;
				CircleCount = 0;
			}
		}

		private static Statistics s_statistics;

		public static ref Statistics Stats => ref s_statistics;
	}
}

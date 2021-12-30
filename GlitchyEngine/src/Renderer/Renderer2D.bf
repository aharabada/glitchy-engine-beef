using GlitchyEngine.Math;
using System.Collections;
using System;
using System.Diagnostics;
using GlitchyEngine.Renderer.Text;

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

		struct QueueQuad: this(Matrix Transform, ColorRGBA Color, Texture2D Texture, float Depth, Vector4 uvTransform) { }

		struct QueueCircle : QueueQuad
		{
			public float InnerRadius;

			public this(Matrix Transform, ColorRGBA Color, Texture2D Texture, float Depth, Vector4 uvTransform, float innerRadius)
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

		private static GeometryBinding s_batchBinding;
		private static GeometryBinding s_circleBatchBinding;
		private static VertexBuffer s_instanceBuffer;
		private static VertexBuffer s_circleInstanceBuffer;
		
		private static BatchVertex[] s_rawInstances;
		private static CircleBatchVertex[] s_rawCircleInstances;
		private static uint32 s_setInstances;

		private static List<QueueQuad> s_instanceQueue;
		private static List<QueueCircle> s_circleInstanceQueue;

		private static DrawOrder s_drawOrder;

		/// The effect that is currently used to draw the sprites.
		private static Effect s_currentEffect;
		private static Effect s_currentCircleEffect;

		private static void InitEffect()
		{
			s_batchEffect = new Effect("content\\Shaders\\spritebatch.hlsl");
			s_circleBatchEffect = new Effect("content\\Shaders\\circlebatch.hlsl");
		}

		private static void InitGeometry()
		{
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
			{
				s_instanceBuffer = new VertexBuffer(typeof(BatchVertex), 1024, .Dynamic, .Write);
				s_instanceBuffer.SetData(0);

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
	
				VertexLayout batchLayout = new VertexLayout(vertexElements, true, s_batchEffect.VertexShader);
	
				s_batchBinding = new GeometryBinding();
				s_batchBinding.SetVertexLayout(batchLayout..ReleaseRefNoDelete());
				s_batchBinding.SetPrimitiveTopology(.TriangleList);
	
				s_batchBinding.SetVertexBufferSlot(s_quadGeometry.GetVertexBuffer(0), 0);
				s_batchBinding.SetIndexBuffer(s_quadGeometry.GetIndexBuffer(), 0);
	
				s_batchBinding.SetVertexBufferSlot(s_instanceBuffer, 1);
	
				s_rawInstances = new BatchVertex[1024];
				s_setInstances = 0;
	
				s_instanceQueue = new List<QueueQuad>(1024);
			}
			
			{
				s_circleInstanceBuffer = new VertexBuffer(typeof(CircleBatchVertex), 1024, .Dynamic, .Write);
				s_circleInstanceBuffer.SetData(0);

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

				using(var circleBatchLayout = new VertexLayout(vertexElements, true, s_circleBatchEffect.VertexShader))
				{
					s_circleBatchBinding.SetVertexLayout(circleBatchLayout);
				}
	
				s_circleBatchBinding.SetVertexBufferSlot(s_quadGeometry.GetVertexBuffer(0), 0);
				s_circleBatchBinding.SetIndexBuffer(s_quadGeometry.GetIndexBuffer(), 0);

				s_circleBatchBinding.SetVertexBufferSlot(s_circleInstanceBuffer, 1);
	
				s_rawCircleInstances = new CircleBatchVertex[1024];

				s_circleInstanceQueue = new List<QueueCircle>(1024);
			}
		}

		private static void InitWhitetexture()
		{
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
			Log.EngineLogger.AssertDebug(s_initialized, "Renderer2D was not initialized.");

			FontRenderer.Deinit();

			s_batchEffect.ReleaseRef();
			s_circleBatchEffect.ReleaseRef();

			s_quadGeometry.ReleaseRef();

			s_whiteTexture.ReleaseRef();
			
			s_batchBinding.ReleaseRef();
			s_circleBatchBinding.ReleaseRef();
			s_instanceBuffer.ReleaseRef();
			s_circleInstanceBuffer.ReleaseRef();

			delete s_rawInstances;
			delete s_rawCircleInstances;
			delete s_instanceQueue;
			delete s_circleInstanceQueue;

			s_currentEffect?.ReleaseRef();
			s_currentCircleEffect?.ReleaseRef();

#if DEBUG
			s_initialized = false;
#endif
		}

		public static void BeginScene(OrthographicCamera camera, DrawOrder drawOrder = .SortByTexture, Effect effect = null, Effect circleEffect = null)
		{
			Log.EngineLogger.AssertDebug(s_initialized, "Renderer2D was not initialized.");
			Log.EngineLogger.AssertDebug(!s_sceneRunning, "You have to call EndScene before you can make another call to BeginScene.");

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

		public static void EndScene()
		{
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");

			Flush();
#if DEBUG
			s_sceneRunning = false;
#endif
		}

		public static void Flush()
		{
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");

			if(s_drawOrder != .Immediate)
				DrawDeferred();
		}

		/// Adds a quad instance to the instance queue.
		[Inline]
		private static void QueueQuadInstance(Matrix transform, ColorRGBA color, Texture2D texture, float depth, Vector4 uvTransform)
		{
			s_instanceQueue.Add(QueueQuad(transform, color, texture ?? s_whiteTexture, depth, uvTransform));
		}
		
		/// Adds a circle instance to the instance queue.
		[Inline]
		private static void QueueCircleInstance(Matrix transform, ColorRGBA color, Texture2D texture, float depth, Vector4 uvTransform, float innerRadius)
		{
			s_circleInstanceQueue.Add(QueueCircle(transform, color, texture ?? s_whiteTexture, depth, uvTransform, innerRadius));
		}
		
		private static void FlushInstances()
		{
			if(s_setInstances == 0)
				return;

			s_instanceBuffer.SetData<BatchVertex>(s_rawInstances.Ptr, s_setInstances, 0, .WriteDiscard);
			
			s_currentEffect.Bind(Renderer._context);
			s_batchBinding.InstanceCount = s_setInstances;
			s_batchBinding.Bind();
			RenderCommand.DrawIndexedInstanced(s_batchBinding);

			s_setInstances = 0;
		}

		private static void FlushCircleInstances()
		{
			if(s_setInstances == 0)
				return;

			s_circleInstanceBuffer.SetData<CircleBatchVertex>(s_rawCircleInstances.Ptr, s_setInstances, 0, .WriteDiscard);
			
			s_currentCircleEffect.Bind(Renderer._context);
			s_circleBatchBinding.InstanceCount = s_setInstances;
			s_circleBatchBinding.Bind();
			RenderCommand.DrawIndexedInstanced(s_circleBatchBinding);

			s_setInstances = 0;
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
			switch(s_drawOrder)
			{
			case .SortByTexture:
				s_instanceQueue.Sort(scope => TextureComparison);
				s_circleInstanceQueue.Sort(scope => TextureComparison);
			case .BackToFront:
				s_instanceQueue.Sort(scope => BackToFrontComparison);
				s_circleInstanceQueue.Sort(scope => BackToFrontComparison);
			case .FrontToBack:
				s_instanceQueue.Sort(scope => FrontToBackComparison);
				s_circleInstanceQueue.Sort(scope => FrontToBackComparison);
			case .Immediate:
			default:
				Log.EngineLogger.Error("Unknown instance draw order.");
			}
		}

		private static void DrawDeferred()
		{
			if(s_instanceQueue.IsEmpty && s_circleInstanceQueue.IsEmpty)
				return;

			SortInstances();

			DrawDeferredQuads();
			DrawDeferredCircles();
		}

		private static void DrawDeferredQuads()
		{
			if(s_instanceQueue.IsEmpty)
				return;

			Texture2D texture = s_instanceQueue[0].Texture;
			s_currentEffect.SetTexture("Texture", texture);

			s_setInstances = 0;

			for(int i < s_instanceQueue.Count)
			{
				var quad = ref s_instanceQueue[i];

				// flush every time the texture changes
				if(quad.Texture != texture)
				{
					FlushInstances();

					texture = quad.Texture;
					s_currentEffect.SetTexture("Texture", texture);
				}

				s_rawInstances[s_setInstances++] = .(quad.Transform, quad.Color, quad.uvTransform);
				
				if(s_setInstances == s_rawInstances.Count)
				{
					FlushInstances();
				}
			}

			FlushInstances();

			s_instanceQueue.Clear();
		}

		private static void DrawDeferredCircles()
		{
			if(s_circleInstanceQueue.IsEmpty)
				return;

			Texture2D texture = s_circleInstanceQueue[0].Texture;
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

		// Primitives

		// Quad

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
		
		public static void DrawQuad(Vector2 position, Vector2 size, float rotation, Texture2D texture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			DrawQuad(Vector3(position, 0.0f), size, rotation, texture, color, uvTransform);
		}
		
		public static void DrawQuadPivotCorner(Vector2 position, Vector2 size, float rotation, Texture2D texture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			DrawQuadPivotCorner(Vector3(position, 0.0f), size, rotation, texture, color, uvTransform);
		}

		public static void DrawQuad(Vector3 position, Vector2 size, float rotation, Texture2D texture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");
				
			Matrix transform = Matrix.Translation(position) * Matrix.RotationZ(rotation) * Matrix.Scaling(size.X, size.Y, 1.0f);

			QueueQuadInstance(transform, color, texture, position.Z, uvTransform);

			if(s_drawOrder == .Immediate)
			{
				DrawDeferred();
			}
		}

		public static void DrawQuad(Matrix transform, Texture2D texture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");

			QueueQuadInstance(transform, color, texture, transform.Translation.Z, uvTransform);

			if(s_drawOrder == .Immediate)
			{
				DrawDeferred();
			}
		}

		public static void DrawQuadPivotCorner(Vector3 position, Vector2 size, float rotation, Texture2D texture, ColorRGBA color = .White, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			DrawQuad(position + Vector3(size.X / 2, size.Y / -2, 0), size, rotation, texture, color, uvTransform);
		}

		// Circle

		public static void DrawCircle(Vector2 position, Vector2 size, ColorRGBA color, float innerRadius = 1.0f)
		{
			DrawCircle(Vector3(position, 0.0f), size, s_whiteTexture, color, innerRadius);
		}

		public static void DrawCircle(Vector3 position, Vector2 size, ColorRGBA color, float innerRadius = 1.0f)
		{
			DrawCircle(position, size, s_whiteTexture, color, innerRadius);
		}

		public static void DrawCircle(Vector2 position, Vector2 size, float rotation, Texture2D texture, ColorRGBA color = .White, float innerRadius = 1.0f, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			DrawCircle(Vector3(position, 0.0f), size, texture, color, innerRadius, uvTransform);
		}

		public static void DrawCircle(Vector3 position, Vector2 size, Texture2D texture, ColorRGBA color = .White, float innerRadius = 1.0f, Vector4 uvTransform = .(0, 0, 1, 1))
		{
			Log.EngineLogger.AssertDebug(s_sceneRunning, "Missing call of BeginScene.");
				
			Matrix transform = Matrix.Translation(position) * Matrix.Scaling(size.X, size.Y, 1.0f);
			
			QueueCircleInstance(transform, color, texture, position.Z, uvTransform, innerRadius);

			if(s_drawOrder == .Immediate)
			{
				DrawDeferred();
			}
		}
	}
}

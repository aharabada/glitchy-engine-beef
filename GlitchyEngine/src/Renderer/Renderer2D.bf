using GlitchyEngine.Math;
using System.Collections;
using System;
using System.Diagnostics;

namespace GlitchyEngine.Renderer
{
	using internal GlitchyEngine.Renderer;

	public class Renderer2D
	{
		struct RenderVertex : IVertexData
		{
			public Vector2 Position;

			public this(Vector2 position)
			{
				Position = position;
			}

			public this(float x, float y)
			{
				Position = .(x, y);
			}

			public static VertexElement[] VertexElements ~ delete _;

			public static VertexElement[] IVertexData.VertexElements => VertexElements;

			static this()
			{
				VertexElements = new VertexElement[]
				(
					VertexElement(.R32G32_Float, "POSITION")
				);
			}
		}

		[Ordered]
		struct BatchVertex
		{
			public Matrix Transform;
			public Color Color;

			public this(Matrix transform, Color color)
			{
				Transform = transform;
				Color = color;
			}
		}

		private GraphicsContext _context ~ _?.ReleaseRef();

		private Vector2 _virtualResolution;

		private Effect quadEffect ~ _?.ReleaseRef();
		private VertexLayout layout ~ delete _;
		private GeometryBinding quadBinding ~ _?.ReleaseRef();
		
		private Effect instancingEffect ~ _?.ReleaseRef();
		private VertexLayout instancingLayout ~ delete _;
		private GeometryBinding instancingBinding ~ _?.ReleaseRef();
		private VertexBuffer instanceBuffer ~ _?.ReleaseRef();
		
		private BatchVertex[] _rawInstances = new BatchVertex[1024] ~ delete _;
		private uint32 _setInstances = 0;

		public this(GraphicsContext context, EffectLibrary effectLibrary)
		{
			_context = context..AddRef();
			Init(effectLibrary);
			InitInstancing(effectLibrary);
		}

		void Init(EffectLibrary effectLibrary)
		{
			quadEffect = effectLibrary.Load("content\\Shaders\\render2dShader.hlsl", "Renderer2D");

			layout = new VertexLayout(_context, RenderVertex.VertexElements, quadEffect.VertexShader);

			VertexBuffer quadVertices = new VertexBuffer(_context, typeof(RenderVertex), 4, .Immutable);

			RenderVertex[4] vertices = .(
				.(0, 0),
				.(0, 1),
				.(1, 1),
				.(1, 0)
				);

			quadVertices.SetData(vertices);

			IndexBuffer quadIndices = new IndexBuffer(_context, 6, .Immutable);

			uint16[6] indices = .(
					0, 1, 2,
					2, 3, 0
				);

			quadIndices.SetData(indices);

			quadBinding = new GeometryBinding(_context);
			quadBinding.SetVertexLayout(layout);
			quadBinding.SetPrimitiveTopology(.TriangleList);
			quadBinding.SetVertexBufferSlot(quadVertices, 0);
			quadBinding.SetIndexBuffer(quadIndices);

			quadVertices.ReleaseRef();
			quadIndices.ReleaseRef();
		}

		void InitInstancing(EffectLibrary effectLibrary)
		{
			instancingEffect = effectLibrary.Load("content\\Shaders\\render2dShaderInst.hlsl", "Renderer2DInstancing");

			instanceBuffer = new VertexBuffer(_context, typeof(BatchVertex), 1024, .Dynamic, .Write);
			instanceBuffer.SetData(0);

			VertexElement[] vertexElements = scope .(
				VertexElement(.R32G32_Float, "POSITION", 0, 0, 0, .PerVertexData, 0),
				
				VertexElement(.R32G32B32A32_Float, "TRANSFORM", 0, 1, (.)-1, .PerInstanceData, 1),
				VertexElement(.R32G32B32A32_Float, "TRANSFORM", 1, 1, (.)-1, .PerInstanceData, 1),
				VertexElement(.R32G32B32A32_Float, "TRANSFORM", 2, 1, (.)-1, .PerInstanceData, 1),
				VertexElement(.R32G32B32A32_Float, "TRANSFORM", 3, 1, (.)-1, .PerInstanceData, 1),
				VertexElement(    .R8G8B8A8_UNorm,     "COLOR", 0, 1, (.)-1, .PerInstanceData, 1)
			);

			instancingLayout = new VertexLayout(_context, vertexElements, instancingEffect.VertexShader);

			instancingBinding = new GeometryBinding(_context);
			instancingBinding.SetVertexLayout(instancingLayout);
			instancingBinding.SetPrimitiveTopology(.TriangleList);
			instancingBinding.SetVertexBufferSlot(quadBinding.GetVertexBuffer(0), 0);
			instancingBinding.SetVertexBufferSlot(instanceBuffer, 1);
			instancingBinding.SetIndexBuffer(quadBinding.GetIndexBuffer(), 0);
		}

		Matrix _projection;

		DrawOrder _drawOrder;

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

		/**
		 * Initializes the renderer.
		 * @param drawOrder Determines if and how the sprites will be ordered before rendering.
		 * @param virtualResolution The virtual resolution used for rendering.
		 *			Can be used to draw resolution independent stuff. // TODO: find a better explanation
		 */ // TODO: RenderMode (Immediate, Deferred)
		public void Begin(DrawOrder drawOrder = .SortByTexture, Vector2 virtualResolution = .Zero, float maxDepth = 100)
		{
			_drawOrder = drawOrder;

			_virtualResolution = virtualResolution;

			if(virtualResolution == .Zero)
			{
				_virtualResolution = .(_context.SwapChain.BackbufferViewport.Width, _context.SwapChain.BackbufferViewport.Height);
			}
			
			_projection = .(2.0f / _virtualResolution.X, 0, 0, 0,
							0, -2.0f / _virtualResolution.Y, 0, 0,
							0, 0, 1.0f / maxDepth, 0,
							-1, 1, 0, 1);
		}

		struct QueuedQuad: this(Matrix Transform, Color Color, Texture2D Texture, float Depth) { }

		List<QueuedQuad> _quads = new .(128) ~ delete _;

		public void Draw(Texture2D texture, float x, float y, float width, float height, Color color = .White, float depth = 0.0f)
		{
			Matrix transform = .(width,      0, 0, 0,
									0, height, 0, 0,
				                    0,      0, 1, 0,
									x,      y, depth, 1) * _projection;

			if(_drawOrder == .Immediate)
			{
				texture.Bind();
	
				quadEffect.Variables["World"].SetData(transform);
				quadEffect.Variables["Color"].SetData(color);
				quadEffect.Variables["HasTexture"].SetData(true);
				quadEffect.Bind(_context);
	
				quadBinding.Bind(_context);
				RenderCommand.DrawIndexed(quadBinding);
			}
			else
			{
				_quads.Add(.(transform, color, texture, depth));
			}
		}

		public void End()
		{
			if(_drawOrder != .Immediate)
			{
				DrawDeferred();
			}
		}

		void FlushInstances()
		{
			if(_setInstances == 0)
				return;

			instanceBuffer.SetData<BatchVertex>(_rawInstances.Ptr, _setInstances, 0, .WriteDiscard);
			
			instancingEffect.Bind(_context);
			instancingBinding.InstanceCount = _setInstances;
			instancingBinding.Bind(_context);
			RenderCommand.DrawIndexedInstanced(instancingBinding);

			_setInstances = 0;
		}

		int TextureComparison(QueuedQuad lhs, QueuedQuad rhs)
		{
			return (int)Internal.UnsafeCastToPtr(lhs.Texture) - (int)Internal.UnsafeCastToPtr(rhs.Texture);
		}
		int FrontToBackComparison(QueuedQuad lhs, QueuedQuad rhs)
		{
			return rhs.Depth <=> lhs.Depth;
		}
		int BackToFrontComparison(QueuedQuad lhs, QueuedQuad rhs)
		{
			return lhs.Depth <=> rhs.Depth;
		}

		private void SortQuads()
		{
			switch(_drawOrder)
			{
			case .SortByTexture:
				_quads.Sort(scope => TextureComparison);
			case .BackToFront:
				_quads.Sort(scope => BackToFrontComparison);
			case .FrontToBack:
				_quads.Sort(scope => FrontToBackComparison);
			default:
			}
		}

		private void DrawDeferred()
		{
			if(_quads.Count == 0)
				return;

			SortQuads();

			Texture2D texture = _quads[0].Texture;
			texture.Bind();

			_setInstances = 0;

			for(int i < _quads.Count)
			{
				var quad = ref _quads[i];

				// flush every time the texture changes
				if(quad.Texture != texture)
				{
					FlushInstances();

					texture = quad.Texture;
					texture.Bind();
				}

				_rawInstances[_setInstances++] = .(quad.Transform, quad.Color);
			}
			
			FlushInstances();
			
			_quads.Clear();

			Debug.Assert(_quads.Count == 0);
		}
	}
}

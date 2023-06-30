using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	static class FullscreenQuad
	{
		static GeometryBinding s_fullscreenQuadGeometry;

		public static void Init()
		{
			s_fullscreenQuadGeometry = new GeometryBinding();
			s_fullscreenQuadGeometry.SetPrimitiveTopology(.TriangleList);

			using(var quadVertices = new VertexBuffer(typeof(float4), 3, .Immutable))
			{
				float4[4] vertices = .(
				.(-1, 1, 0, 0),
				.( 3, 1, 2, 0),
				.(-1,-3, 0, 2),
				);

				quadVertices.SetData(vertices);
				s_fullscreenQuadGeometry.SetVertexBufferSlot(quadVertices, 0);
			}

			using(var quadIndices = new IndexBuffer(3, .Immutable))
			{
				uint16[3] indices = .(0, 1, 2);

				quadIndices.SetData(indices);
				s_fullscreenQuadGeometry.SetIndexBuffer(quadIndices);
			}

			VertexElement[] vertexElements = new .(
				VertexElement(.R32G32_Float, "POSITION"),
				VertexElement(.R32G32_Float, "TEXCOORD")
			);

			using (var quadBatchLayout = new VertexLayout(vertexElements, true))
			{
				s_fullscreenQuadGeometry.SetVertexLayout(quadBatchLayout);
			}
		}

		public static void Deinit()
		{
			s_fullscreenQuadGeometry.ReleaseRef();
		}

		public static void Draw()
		{
			s_fullscreenQuadGeometry.Bind();
			RenderCommand.DrawIndexed(s_fullscreenQuadGeometry);
		}
	}

	static class Quad
	{
		static GeometryBinding s_quadGeometry;

		public static void Init()
		{
			s_quadGeometry = new GeometryBinding();
			s_quadGeometry.SetPrimitiveTopology(.TriangleList);

			using(var quadVertices = new VertexBuffer(typeof(float4), 4, .Immutable))
			{
				float4[4] vertices = .(
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
				uint16[6] indices = .(0, 1, 2, 2, 3, 0);

				quadIndices.SetData(indices);
				s_quadGeometry.SetIndexBuffer(quadIndices);
			}

			VertexElement[] vertexElements = new .(
				VertexElement(.R32G32_Float, "POSITION"),
				VertexElement(.R32G32_Float, "TEXCOORD")
			);

			using (var quadBatchLayout = new VertexLayout(vertexElements, true))
			{
				s_quadGeometry.SetVertexLayout(quadBatchLayout);
			}
		}

		public static void Deinit()
		{
			s_quadGeometry.ReleaseRef();
		}

		public static void Draw()
		{
			s_quadGeometry.Bind();
			RenderCommand.DrawIndexed(s_quadGeometry);
		}
	}
}
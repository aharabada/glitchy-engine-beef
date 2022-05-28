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

			using(var quadVertices = new VertexBuffer(typeof(Vector4), 3, .Immutable))
			{
				Vector4[4] vertices = .(
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
}
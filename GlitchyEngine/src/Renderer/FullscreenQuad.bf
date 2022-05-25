namespace GlitchyEngine.Renderer
{
	static class FullscreenQuad
	{
		//static GeometryBinding s_fullscreenQuadGeometry;

		public static void Init()
		{
			/*s_fullscreenQuadGeometry = new GeometryBinding();
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
			}*/
		}

		public static void Deinit()
		{
			//s_fullscreenQuadGeometry.ReleaseRef();
		}
	}
}
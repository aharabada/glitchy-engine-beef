using GlitchyEngine.Math;
using GlitchyEngine.World;
using System;

namespace GlitchyEngine.Renderer
{
	/// Provides functionality for debugging
	public static class DebugRenderer
	{
		private static GeometryBinding CoordinateCross;
		
		public static bool DrawEntityTransforms = true;

		public static void Init()
		{
			CreateCoordinateCross();
		}

		private static void CreateCoordinateCross()
		{
			CoordinateCross = new GeometryBinding();
			//CoordinateCross.PrimitiveTopology
		}

		public static void Deinit()
		{
			CoordinateCross.ReleaseRef();
		}

		/**
		 * Draws a coordinate cross for the given matrix.
		 * @param transform The transform matrix.
		 * @param length Can be used to set a fixed length for the rendered lines that represent the axes.
		 * 		 Set to 0 if you want transform to affect the length of the lines.
		 */
		public static void DrawCoordinateCross(Matrix transform, float length = 0.0f)
		{
			var transform;

			if(length != 0.0f)
			{
				transform.Columns[0] = normalize(transform.Columns[0]) * length;
				transform.Columns[1] = normalize(transform.Columns[1]) * length;
				transform.Columns[2] = normalize(transform.Columns[2]) * length;
			}

			Renderer.DrawLine(.Zero, .Right,   .Red,  transform);
			Renderer.DrawLine(.Zero, .Up,      .Lime, transform);
			Renderer.DrawLine(.Zero, .Forward, .Blue, transform);
		}
		
		//static GeometryBinding _frustumGeometry;
		//static VertexBuffer _frustumVertices;

		/**
		 * Draws the view frustum for the given camera transform and projection.
		 * @param worldTransform The cameras transform matrix.
		 * @param projection The cameras projection matrix.
		 * @param observerVP The view projection of the rendering camera.
		 * @param color The color of the frustum.
		 */
		public static void DrawViewFrustum(Matrix worldTransform, Matrix projection, ColorRGBA color = .Red)
		{
			/*if (_frustumGeometry == null)
			{
				_frustumGeometry = new GeometryBinding();
				_frustumGeometry.SetPrimitiveTopology(.LineList);

				_frustumVertices = new VertexBuffer(typeof(float4), 8, .Dynamic, .Write);
				_frustumGeometry.SetVertexBufferSlot(_frustumVertices, 0);

				using (IndexBuffer indexBuffer = new IndexBuffer(24, .Immutable))
				{
					uint16[24] indices = .(
						0, 1,
						1, 2,
						2, 3,
						3, 0,

						4, 5,
						5, 6,
						6, 7,
						7, 4,

						0, 4,
						1, 5,
						2, 6,
						3, 7);

					indexBuffer.SetData(indices);

					_frustumGeometry.SetIndexBuffer(indexBuffer);
				}
			}*/

			uint16[24] indices = .(
				0, 1,
				1, 2,
				2, 3,
				3, 0,

				4, 5,
				5, 6,
				6, 7,
				7, 4,

				0, 4,
				1, 5,
				2, 6,
				3, 7);
			
			float4[8] corners;
			// Perspective
			if(projection._43 != 0.0f)
			{
				// near plane for perspective projection, far plane if reversed
				float d1 = -projection._34 / projection._33;

				float d2 = projection._34 / (1.0f - projection._33);

				float gOverS = projection._11;
				float g = projection._22;

				//var corners = //(float4*)&_vbFrustum.Data;

				if(Math.Abs(d1) >= 10000)
				{
					d1 = 10.0f;
					corners[0] = .( d1 / gOverS,     d1 / g    , d1, 0.0f);
					corners[1] = .( corners[0].X, -corners[0].Y, d1, 0.0f);
					corners[2] = .(-corners[0].X, -corners[0].Y, d1, 0.0f);
					corners[3] = .(-corners[0].X,  corners[0].Y, d1, 0.0f);
				}
				else
				{
					corners[0] = .( d1 / gOverS,     d1 / g    , d1, 1.0f);
					corners[1] = .( corners[0].X, -corners[0].Y, d1, 1.0f);
					corners[2] = .(-corners[0].X, -corners[0].Y, d1, 1.0f);
					corners[3] = .(-corners[0].X,  corners[0].Y, d1, 1.0f);
				}

				if(Math.Abs(d2) >= 10000)
				{
					d2 = 10.0f;

					corners[4] = .(  d2 / gOverS,    d2 / g    , d2, 0.0f);
					corners[5] = .( corners[4].X, -corners[4].Y, d2, 0.0f);
					corners[6] = .(-corners[4].X, -corners[4].Y, d2, 0.0f);
					corners[7] = .(-corners[4].X,  corners[4].Y, d2, 0.0f);
				}
				else
				{
					corners[4] = .(  d2 / gOverS,    d2 / g    , d2, 1.0f);
					corners[5] = .( corners[4].X, -corners[4].Y, d2, 1.0f);
					corners[6] = .(-corners[4].X, -corners[4].Y, d2, 1.0f);
					corners[7] = .(-corners[4].X,  corners[4].Y, d2, 1.0f);
				}
			}
			else
			{
				float l = -(projection._14 + 1.0f) / projection._11;
				float r = (1.0f - projection._14) / projection._11;

				float t = -(projection._24 + 1.0f) / projection._22;
				float b = (1.0f - projection._24) / projection._22;

				float n = -projection._34 / projection._33;
				float f = (1 - projection._34) / projection._33;
				
				//var corners = (float4*)&_vbFrustum.Data;
				corners[0] = .(r, t, n, 1.0f);
				corners[1] = .(r, b, n, 1.0f);
				corners[2] = .(l, b, n, 1.0f);
				corners[3] = .(l, t, n, 1.0f);
				
				corners[4] = .(r, t, f, 1.0f);
				corners[5] = .(r, b, f, 1.0f);
				corners[6] = .(l, b, f, 1.0f);
				corners[7] = .(l, t, f, 1.0f);
			}

			for (int i = 0; i < indices.Count; i += 2)
			{
				uint16 index0 = indices[i];
				uint16 index1 = indices[i + 1];

				Renderer2D.DrawLine(worldTransform * corners[index0], worldTransform * corners[index1], color);
			}
		}

		public static void Render(EcsWorld world)
		{
			if(DrawEntityTransforms)
			{
				for(var (entity, transform) in world.Enumerate<TransformComponent>())
				{
					DrawCoordinateCross(transform.WorldTransform);
				}
			}
		}
	}
}

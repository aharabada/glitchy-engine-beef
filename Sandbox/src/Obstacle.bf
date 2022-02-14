using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;

namespace Sandbox
{
	class Obstacle
	{
		public Vector2 Position;

		public float HoleSize = 4.5f;

		public static float Speed = -2.0f;

		public static float ScreenWidth;

		public static Random random = new .() ~ delete _;

		public bool Dead;

		public void Update(GameTime gameTime)
		{
			Position.X += Speed * gameTime.DeltaTime;

			if (Position.X < -ScreenWidth - 1)
			{
				Dead = true;
			}
		}

		static Matrix mat = Matrix.Scaling(2.5f, 5, 1) * Matrix.RotationZ(MathHelper.PiOverFour);

		public void Draw(ColorRGBA color)
		{
			Matrix matty = mat;
			matty.Translation.X = Position.X;

			matty.Translation.Y = Position.Y - HoleSize;
			Renderer2D.DrawQuad(matty, color);

			matty.Translation.Y = Position.Y + HoleSize;
			Renderer2D.DrawQuad(matty, color);
		}
	}
}
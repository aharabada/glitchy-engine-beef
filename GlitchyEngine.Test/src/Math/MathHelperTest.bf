using System;
using GlitchyEngine.Math;

namespace GlitchyEngine.Test.Math
{
	static class MathHelperTest
	{
		[Test]
		public static void TestDegToRad()
		{
			{
				float deg = 0;
				float rad = MathHelper.ToRadians(deg);
				Test.Assert(rad == 0.0f);
			}
			
			{
				float deg = 45;
				float rad = MathHelper.ToRadians(deg);
				Test.Assert(rad == MathHelper.PiOverFour);
			}
			
			{
				float deg = 180;
				float rad = MathHelper.ToRadians(deg);
				Test.Assert(rad == MathHelper.Pi);
			}

			{
				float deg = -360;
				float rad = MathHelper.ToRadians(deg);
				Test.Assert(rad == -MathHelper.TwoPi);
			}
		}

		[Test]
		public static void TestRadToDeg()
		{
			{
				float rad = 0;
				float deg = MathHelper.ToDegrees(rad);
				Test.Assert(deg == 0.0f);
			}
			
			{
				float rad = MathHelper.PiOverFour;
				float deg = MathHelper.ToDegrees(rad);
				Test.Assert(deg == 45);
			}
			
			{
				float rad = MathHelper.Pi;
				float deg = MathHelper.ToDegrees(rad);
				Test.Assert(deg == 180);
			}

			{
				float rad = -MathHelper.TwoPi;
				float deg = MathHelper.ToDegrees(rad);
				Test.Assert(deg == -360);
			}
		}
	}
}

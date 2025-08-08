using System;
using GlitchyEngine.Math;

namespace GlitchyEngine.Test.Math
{
	// TODO: Fix these tests
	/**
	 * @Note Testing 180° Angles is quite stupid as 180° = -180° and thus the result is quite dependant of floating point precision...
	 */
	static class QuaternionTest
	{
		static bool QuatEquals(Quaternion q1, Quaternion q2, float delta = 0.0001f)
		{
			return Math.Abs(q1.X - q2.X) < delta && Math.Abs(q1.Y - q2.Y) < delta &&
				Math.Abs(q1.Z - q2.Z) < delta && Math.Abs(q1.W - q2.W) < delta;
		}

		static bool Vector3Equals(float3 v1, float3 v2, float delta = 0.0001f)
		{
			return Math.Abs(v1.X - v2.X) < delta && Math.Abs(v1.Y - v2.Y) < delta &&
				Math.Abs(v1.Z - v2.Z) < delta;
		}

		static bool FloatEquals(float l, float r, float delta = 0.0001f)
		{
			return Math.Abs(l - r) < delta;
		}

		//[Test]
		public static void TestAxisAngleToQuaternion()
		{
			// angle in degrees
			void Test(float3 axis, float angle, Quaternion expectedQuat)
			{
				float angleRad = MathHelper.ToRadians(angle);
				Quaternion result = .FromAxisAngle(axis, angleRad);

				Quaternion resultNormalized = .Normalize(result);
				Quaternion expectedNormalized = .Normalize(expectedQuat);

				Test.Assert(QuatEquals(resultNormalized, expectedNormalized));
			}

			// Reference for conversions: https://www.andre-gaschler.com/rotationconverter/
			
			Test(.(0, 0, 0), 55, Quaternion.Identity);

			// x: 90°
			Test(.(1, 0, 0), 90, Quaternion(1, 0, 0, 1));
			// y: 90°
			Test(.(0, 1, 0), 90, Quaternion(0, 1, 0, 1));
			// z: 90°
			Test(.(0, 0, 1), 90, Quaternion(0, 0, 1, 1));

			Test(.(1, 1, 0), 90, Quaternion(0.5f, 0.5f, 0, 0.707107f));

			Test(.(1, 1, 1), 90, Quaternion(0.4082483f, 0.4082483f, 0.4082483f, 0.7071068f));

			Test(.(0.3f, 0.5f, 0.4f), -25, Quaternion(-0.0918276f, -0.1530459f, -0.1224367f, 0.976296f));

			Test(.(0.3f, -0.5f, 0.4f), -25, Quaternion(-0.0918276f, 0.1530459f, -0.1224367f, 0.976296f));
		}
		
		//[Test]
		public static void TestQuaternionToAxisAngle()
		{
			// angle in degrees
			void Test(Quaternion quat, float3 expectedAxis, float expectedAngle)
			{
				Quaternion quatNrm = .Normalize(quat);
				(float3 resultAxis, float resultAngle) = quatNrm.ToAxisAngle();

				resultAxis = normalize(resultAxis);
				resultAngle = MathHelper.ToDegrees(resultAngle);

				float3 nrmExpectedAxis = normalize(expectedAxis);

				Test.Assert(Vector3Equals(resultAxis, nrmExpectedAxis) && FloatEquals(expectedAngle, resultAngle));
			}

			// Reference for conversions: https://www.andre-gaschler.com/rotationconverter/
			
			Test(Quaternion.Identity, .(0, 0, 0), 0);

			// x: 90°
			Test(Quaternion(1, 0, 0, 1), .(1, 0, 0), 90);
			// y: 90°
			Test(Quaternion(0, 1, 0, 1), .(0, 1, 0), 90);
			// z: 90°
			Test(Quaternion(0, 0, 1, 1), .(0, 0, 1), 90);

			Test(Quaternion(0.5f, 0.5f, 0, 0.707107f), .(1, 1, 0), 90);

			Test(Quaternion(0.4082483f, 0.4082483f, 0.4082483f, 0.7071068f), .(1, 1, 1), 90);

			Test(Quaternion(-0.0918276f, -0.1530459f, -0.1224367f, 0.976296f), .(-0.4242643f, -0.7071067f, -0.5656853f), 24.9999988f);
			Test(Quaternion(-0.0918276f, 0.1530459f, -0.1224367f, 0.976296f), .(-0.4242643f, 0.7071067f, -0.5656853f), 24.9999988f);
		}

		//[Test]
		public static void TestEulerToQuaternion()
		{
			void Test(float3 inEuler, Quaternion expectedQuat)
			{
				Quaternion result = .FromEulerAngles(MathHelper.ToRadians(inEuler.Y), MathHelper.ToRadians(inEuler.X), MathHelper.ToRadians(inEuler.Z));

				Test.Assert(QuatEquals(result, expectedQuat));
			}

			Test(float3.Zero, Quaternion.Identity);

			// X: 90°
			Test(.(90, 0, 0), Quaternion(1, 0, 0, 1)..Normalize());
			
			// Y: 90°
			Test(.(0, 90, 0), Quaternion(0, 1, 0, 1)..Normalize());

			// Z: 90°
			Test(.(0, 0, 90), Quaternion(0, 0, 1, 1)..Normalize());
			
			// X: 90° Y: 90°
			Test(.(90, 90, 0), Quaternion(1, 1, -1, 1)..Normalize());

			// 90° 45° 30°
			Test(.(90, 45, 30), Quaternion(0.7010574f, 0.4304593f, -0.092296f, 0.5609855f)..Normalize());

			// 105° 90° 0°
			Test(.(105, 90, 0), Quaternion(0.560986f, 0.430459f, -0.560986f, 0.430459f)..Normalize());
			
			// 180° 90° -75°
			Test(.(180, 90, -75), Quaternion(0.5609855f, -0.4304593f, -0.5609855f, 0.4304593f)..Normalize());
		}
		
		//[Test]
		public static void TestQuaternionToEuler()
		{
			void Test(Quaternion inQuat, float3 expectedEuler)
			{
				Quaternion nrmInQuat = .Normalize(inQuat);

				float3 result = Quaternion.ToEulerAngles(nrmInQuat);
				float3 resultDeg = MathHelper.ToDegrees(result);

				Test.Assert(Vector3Equals(resultDeg, expectedEuler));
			}

			Test(Quaternion.Identity, float3.Zero);

			// X: 90°
			Test(Quaternion(1, 0, 0, 1), .(90, 0, 0));
			
			// Y: 90°
			Test(Quaternion(0, 1, 0, 1), .(0, 90, 0));

			// Z: 90°
			Test(Quaternion(0, 0, 1, 1), .(0, 0, 90));
			
			// X: 90° Y: 90°
			Test(Quaternion(1, 1, -1, 1), .(90, 90, 0));

			// 90° 45° 30°
			Test(Quaternion(0.7010574f, 0.4304593f, -0.092296f, 0.5609855f), .(90, 45, 30));

			// 105° 90° 0°
			Test(Quaternion(0.560986f, 0.430459f, -0.560986f, 0.430459f), .(105, 90, 0));
			
			// 180° 90° -75°
			Test(Quaternion(0.5609855f, -0.4304593f, -0.5609855f, 0.4304593f), .(180, 90, -75));
		}
		
		//[Test]
		public static void TestEulerToQautToEuler()
		{
			void Test(float yaw, float pitch, float roll)
			{
				Quaternion quat = .FromEulerAngles(MathHelper.ToRadians(yaw), MathHelper.ToRadians(pitch), MathHelper.ToRadians(roll));

				float3 result = Quaternion.ToEulerAngles(quat);

				result = .(MathHelper.ToDegrees(result.X), MathHelper.ToDegrees(result.Y), MathHelper.ToDegrees(result.Z));

				Test.Assert(Vector3Equals(.(pitch, yaw, roll), result));
			}

			Test(0, 90, 0);
			Test(90, 0, 0);
			Test(0, 0, 90);

			Test(90, 90, 0);
			
			Test(90, 45, 0);

			Test(90, 45, 30);

			Test(105, 90, 0);

			Test(179, 90, -75);
		}
	}
}

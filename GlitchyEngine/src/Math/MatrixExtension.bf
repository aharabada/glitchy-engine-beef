using System;
using GlitchyEngine.Math;
using GlitchyEngine;

namespace DirectX.Math
{
	extension Matrix
	{
		public static Self RotationQuaternion(Quaternion quat)
		{
			float xSq = quat.X * quat.X;
			float ySq = quat.Y * quat.Y;
			float zSq = quat.Z * quat.Z;

			float xy = quat.X * quat.Y;
			float xz = quat.X * quat.Z;
			float xw = quat.X * quat.W;
			float yz = quat.Y * quat.Z;
			float yw = quat.Y * quat.W;
			float zw = quat.Z * quat.W;

			Self result = .(
				1 - 2 * ySq - 2 * zSq, 2 * xy + 2 * zw, 2 * xz - 2 * yw, 0,
				2 * xy - 2 * zw, 1 - 2 * xSq - 2 * zSq, 2 * yz + 2 * xw, 0,
				2 * xz + 2 * yw, 2 * yz - 2 * xw, 1 - 2 * xSq - 2 * ySq, 0,
				0, 0, 0, 1);

			return result;
		}

		/*[Test]
		static void TestQuaternionToMatrix()
		{
			// Rotation around Z-Axis by 90°
			Quaternion quat = .(0, 0, 0.707107f, 0.707107f);
			quat.Normalize();


		}*/
	}
}

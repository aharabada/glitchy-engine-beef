using System;
using GlitchyEngine.Math;
using GlitchyEngine;

namespace DirectX.Math
{
	extension Matrix
	{
		public static Self RotationQuaternion(Quaternion rotation)
		{
			float xSq = 2 * rotation.X * rotation.X;
			float ySq = 2 * rotation.Y * rotation.Y;
			float zSq = 2 * rotation.Z * rotation.Z;

			float xy = 2 * rotation.X * rotation.Y;
			float xz = 2 * rotation.X * rotation.Z;
			float xw = 2 * rotation.X * rotation.W;
			float yz = 2 * rotation.Y * rotation.Z;
			float yw = 2 * rotation.Y * rotation.W;
			float zw = 2 * rotation.Z * rotation.W;

			Self result = ?;

			result.V._11 = 1 - ySq - zSq;
			result.V._21 = xy + zw;
			result.V._31 = xz - yw;
			result.V._41 = 0;

			result.V._12 = xy - zw;
			result.V._22 = 1 - xSq - zSq;
			result.V._32 = yz + xw;
			result.V._42 = 0;

			result.V._13 = xz + yw;
			result.V._23 = yz - xw;
			result.V._33 = 1 - xSq - ySq;
			result.V._43 = 0;

			result.V._14 = 0;
			result.V._24 = 0;
			result.V._34 = 0;
			result.V._44 = 1;
			
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

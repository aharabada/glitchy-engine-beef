using System;
using GlitchyEngine.Math;
using GlitchyEngine;

namespace DirectX.Math
{
	extension Matrix
	{
		typealias Vec3 = GlitchyEngine.Math.Vector3;

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

		public static void Decompose(Self matrix, out Vec3 position, out Quaternion rotation, out Vec3 scale)
		{
			var matrix;

			// Translation -> get last column
			position = matrix.Translation;
			// Zero translation for next step
			matrix.Translation = .Zero;

			// TODO: this doesn't detect mirroring

			// Extract scaling from matrix
			scale.X = (*(Vec3*)&matrix.Columns[0]).Magnitude();
			scale.Y = (*(Vec3*)&matrix.Columns[1]).Magnitude();
			scale.Z = (*(Vec3*)&matrix.Columns[2]).Magnitude();

			if(MathHelper.IsZero(scale.X) || MathHelper.IsZero(scale.Y) || MathHelper.IsZero(scale.Z))
			{
				rotation = .Identity;
				return;
			}

			// Remove scale from matrix (normalize the columns)
			matrix.Columns[0] /= scale.X;
			matrix.Columns[1] /= scale.Y;
			matrix.Columns[2] /= scale.Z;

			rotation = Quaternion.FromMatrix(matrix);
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

using System;

namespace GlitchyEngine.Math
{
	public struct Quaternion
	{
		public const Quaternion Zero = .();
		public const Quaternion One = .(1.0f, 1.0f, 1.0f, 1.0f);
		public const Quaternion Identity = .(0.0f, 0.0f, 0.0f, 1.0f);

		// qv: (X, Y, Z), sv: W
		public float X, Y, Z, W;

		public this() => this = default;
		
		public this(float x, float y, float z, float w)
		{
			X = x;
			Y = y;
			Z = z;
			W = w;
		}

		public this(Vector3 xy, float z, float w)
		{
			X = xy.X;
			Y = xy.Y;
			Z = z;
			W = w;
		}

		public this(Vector3 xyz, float w)
		{
			X = xyz.X;
			Y = xyz.Y;
			Z = xyz.Z;
			W = w;
		}
		
		public this(Vector4 vector)
		{
			X = vector.X;
			Y = vector.Y;
			Z = vector.Z;
			W = vector.W;
		}

		public Vector3 Axis => .(X, Y, Z);
		public float Scalar => W;

		public void Normalize() mut
		{
			float invLength = 1.0f / Length();

			X *= invLength;
			Y *= invLength;
			Z *= invLength;
			W *= invLength;
		}

		public static Quaternion Normalize(Quaternion q)
		{
			float invLength = 1.0f / Length(q);

			return Quaternion(q.X * invLength, q.Y * invLength, q.Z * invLength, q.W * invLength);
		}

		public float Length()
		{
			return Math.Sqrt([Inline]LengthSquared());
		}

		public static float Length(Quaternion q)
		{
			return Math.Sqrt([Inline]LengthSquared(q));
		}
		
		public float LengthSquared()
		{
			return X * X + Y * Y + Z * Z + W * W;
		}

		public static float LengthSquared(Quaternion q)
		{
			return q.X * q.X + q.Y * q.Y + q.Z * q.Z + q.W * q.W;
		}
		
		public static float Dot(Self l, Self r)
		{
			return l.X * r.X + l.Y * r.Y + l.Z * r.Z + l.W * r.W;
		}
		
		public static Quaternion Lerp(Quaternion a, Quaternion b, float interpolationValue)
		{
			return a + interpolationValue * (b - a);
		}

		public static Quaternion Slerp(Quaternion previousQuaternion, Quaternion nextQuaternion, float interpolationValue)
		{
			// Based on https://github.com/KhronosGroup/glTF-Tutorials/blob/master/gltfTutorial/gltfTutorial_007_Animations.md

			var nextQuaternion;

			float dot = Dot(previousQuaternion, nextQuaternion);
			
			//make sure we take the shortest path in case dot Product is negative
			if(dot < 0.0f)
			{
				nextQuaternion = -nextQuaternion;
				dot = -dot;
			}
			    
			//if the two quaternions are too close to each other, just linear interpolate between the 4D vector
			if(dot > 0.9995f)
			    return Normalize(previousQuaternion + interpolationValue * (nextQuaternion - previousQuaternion));

			//perform the spherical linear interpolation
			var theta_0 = Math.Acos(dot);
			var theta = interpolationValue * theta_0;
			var sin_theta = Math.Sin(theta);
			var sin_theta_0 = Math.Sin(theta_0);

			var scalePreviousQuat = Math.Cos(theta) - dot * sin_theta / sin_theta_0;
			var scaleNextQuat = sin_theta / sin_theta_0;
			return scalePreviousQuat * previousQuaternion + scaleNextQuat * nextQuaternion;
		}

		public static Quaternion FromMatrix(Matrix matrix)
		{
			// http://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/

			var m = matrix.V;

			Quaternion result = ?;

			float tr = m._11 + m._22 + m._33;

			if (tr > 0) { 
			  float S = Math.Sqrt(tr + 1.0f) * 2f; // S=4*result.W 
			  result.W = 0.25f * S;
			  result.X = (m._32 - m._23) / S;
			  result.Y = (m._13 - m._31) / S; 
			  result.Z = (m._21 - m._12) / S; 
			} else if ((m._11 > m._22)&(m._11 > m._33)) { 
			  float S = Math.Sqrt(1.0f + m._11 - m._22 - m._33) * 2f; // S=4*result.X 
			  result.W = (m._32 - m._23) / S;
			  result.X = 0.25f * S;
			  result.Y = (m._12 + m._21) / S; 
			  result.Z = (m._13 + m._31) / S; 
			} else if (m._22 > m._33) { 
			  float S = Math.Sqrt(1.0f + m._22 - m._11 - m._33) * 2f; // S=4*result.Y
			  result.W = (m._13 - m._31) / S;
			  result.X = (m._12 + m._21) / S; 
			  result.Y = 0.25f * S;
			  result.Z = (m._23 + m._32) / S; 
			} else { 
			  float S = Math.Sqrt(1.0f + m._33 - m._11 - m._22) * 2f; // S=4*result.Z
			  result.W = (m._21 - m._12) / S;
			  result.X = (m._13 + m._31) / S;
			  result.Y = (m._23 + m._32) / S;
			  result.Z = 0.25f * S;
			}

			return result;
		}
		
		public static Self operator +(Self value) => value;

		public static Self operator +(Self l, Self r) => Self(l.X + r.X, l.Y + r.Y, l.Z + r.Z, l.W + r.W);

		public static Self operator -(Self value) => Self(-value.X, -value.Y, -value.Z, -value.W);
		
		public static Self operator -(Self l, Self r) => Self(l.X - r.X, l.Y - r.Y, l.Z - r.Z, l.W - r.W);

		public static Self operator *(float l, Self r) => Self(l * r.X, l * r.Y, l * r.Z, l * r.W);


		[Inline]
		public static implicit operator Vector4(in Self value) => *(Vector4*)&value;

		[Inline]
		public static implicit operator Quaternion(in Vector4 value) => *(Quaternion*)&value;

		//public static Quaternion operator +(Self left, Self right) => return .();

		/*
		public static Quaternion Conjugate(Quaternion q)
		{
			return Quaternion(-q.Axis, q.Scalar);
		}

		public static Quaternion Inverse(Quaternion q)
		{
			Quaternion conjugate = Conjugate(q);

			float magSquared = LengthSquared(q);

			return Quaternion(conjugate / magSquared);
		}

		public static Quaternion operator *(Quaternion left, Quaternion right)
		{
			return Quaternion(left.Scalar * right.Axis + right.Scalar * left.Axis + Vector3.Cross(left.Axis, right.Axis),
				left.Scalar * right.Scalar - Vector3.Dot(left.Axis, right.Axis));
		}
		*/

		//public static Quaternion operator /(Quaternion left, float right) => Quaternion(left.X / right, left.Y / right, left.Z / right, left.W / right);
	}
}
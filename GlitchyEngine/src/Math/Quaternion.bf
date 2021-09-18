using System;

namespace GlitchyEngine.Math
{
	public struct Quaternion
	{
		public const Quaternion Zero = .();
		public const Quaternion One = .(1.0f, 1.0f, 1.0f, 1.0f);
		public const Quaternion Identity = .(0.0f, 0.0f, 0.0f, 1.0f);

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

		public Vector3 Vector
		{
			get => .(X, Y, Z);
			set mut
			{
				X = value.X;
				Y = value.Y;
				Z = value.Z;
			}
		}
		
		public float Scalar
		{
			get => W;
			set mut => W = value;
		}

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
		
		public static Self operator /(Self l, float r) => Self(l.X * r, l.Y * r, l.Z * r, l.W * r);

		public static Self operator *(Self l, Self r)
		{
			Quaternion result;

			Vector3 v = l.Vector * r.Vector + (l.W * r.Vector) + (r.W * l.Vector);
			result.X = v.X;
			result.Y = v.Y;
			result.Z = v.Z;
			result.W = (l.W * r.W) - Vector3.Dot(l.Vector, r.Vector);

			return result;
		}
		
		public static Quaternion Conjugate(Quaternion q)
		{
			return Quaternion(-q.Vector, q.Scalar);
		}

		public static Quaternion Inverse(Quaternion q)
		{
			Quaternion conjugate = Conjugate(q);

			float magSquared = LengthSquared(q);

			return conjugate / magSquared;
		}

		[Inline]
#unwarn
		public static implicit operator Vector4(in Self value) => *(Vector4*)&value;

		[Inline]
#unwarn
		public static implicit operator Quaternion(in Vector4 value) => *(Quaternion*)&value;

		public static bool operator ==(Quaternion l, Quaternion r)
		{
			return l.X == r.X && l.Y == r.Y && l.Z == r.Z && l.W == r.W;
		}

		public static bool operator !=(Quaternion l, Quaternion r)
		{
			return l.X != r.X && l.Y != r.Y && l.Z != r.Z && l.W != r.W;
		}

		public (Vector3 Axis, float Angle) ToAxisAngle()
		{
			// scalar part = cos(θ/2)
			// So, we can extract the angle directly.
			float angle = 2.0f * Math.Acos(W);

			// vector part = axis * sin(θ/2)
			// In other words, the vector part is the axis, but with length of sin(θ/2).
			// We assume quaternion is unit length, so subtracting w^2 gives us length of just vector part (aka sin(θ/2)).
			float length = Math.Sqrt(1.0f - (W * W));

			Vector3 axis;

			// Normalize vector part to get the axis!
			if(length == 0)
			{
			    axis = Vector3.Zero;
			}
			else
			{
			    length = 1.0f / length;
			    axis.X = X * length;
			    axis.Y = Y * length;
			    axis.Z = Z * length;
			}

			return (axis, angle);
		}

		public static Quaternion FromAxisAngle(Vector3 axis, float angle)
		{
			float lengthSq = axis.MagnitudeSquared();

			if(lengthSq == 0)
			{
				return .Identity;
			}

			float halfAngle = angle * 0.5f;

			float sin = Math.Sin(halfAngle) / Math.Sqrt(lengthSq);

			Quaternion result;
			result.X = axis.X * sin;
			result.Y = axis.Y * sin;
			result.Z = axis.Z * sin;
			result.W = Math.Cos(halfAngle);

			return result;
		}

		// Assumes YZX-Order meaning Y applied first, Z second and x last
		public static Quaternion FromEulerAngles(float yaw, float pitch, float roll)
		{
			float halfYaw = yaw / 2.0f;
			float halfPitch = pitch / 2.0f;
			float halfRoll = roll / 2.0f;

			float cosYaw = Math.Cos(halfYaw);//heading
			float sinYaw = Math.Sin(halfYaw);
			float cosRoll = Math.Cos(halfRoll);//attitude
			float sinRoll = Math.Sin(halfRoll);
			float cosPitch = Math.Cos(halfPitch);//bank
			float sinPitch = Math.Sin(halfPitch);

			float cosYawCosRoll = cosYaw * cosRoll;
			float sinYawSinRoll = sinYaw * sinRoll;
			float cosYawSinRoll = cosYaw * sinRoll;
			float sinYawCosRoll = sinYaw * cosRoll;

			Quaternion result;

			result.W = cosYawCosRoll * cosPitch - sinYawSinRoll * sinPitch;
			result.X = cosYawCosRoll * sinPitch + sinYawSinRoll * cosPitch;
			result.Y = sinYawCosRoll * cosPitch + cosYawSinRoll * sinPitch;
			result.Z = cosYawSinRoll * cosPitch - sinYawCosRoll * sinPitch;
			
			return result;
		}

		public static Vector3 ToEulerAngles(Quaternion q1)
		{
			// http://www.euclideanspace.com/maths/geometry/rotations/conversions/quaternionToEuler/

			Vector3 result;

		    float sqw = q1.W*q1.W;
		    float sqx = q1.X*q1.X;
		    float sqy = q1.Y*q1.Y;
		    float sqz = q1.Z*q1.Z;
			float unit = sqx + sqy + sqz + sqw; // if normalised is one, otherwise is correction factor
			float test = q1.X*q1.Y + q1.Z*q1.W;
			if (test > 0.499f*unit) { // singularity at north pole
				result.Y = 2.0f * Math.Atan2(q1.X,q1.W);
				result.Z = Math.PI_f / 2.0f;
				result.X = 0.0f;
				return result;
			}
			if (test < -0.499f*unit) { // singularity at south pole
				result.Y = -2.0f * Math.Atan2(q1.X,q1.W);
				result.Z = -Math.PI_f / 2.0f;
				result.X = 0.0f;
				return result;
			}
		    result.Y = Math.Atan2(2*q1.Y*q1.W-2*q1.X*q1.Z , sqx - sqy - sqz + sqw);
			result.Z = Math.Asin(2*test/unit);
			result.X = Math.Atan2(2*q1.X*q1.W-2*q1.Y*q1.Z , -sqx + sqy - sqz + sqw);

			return result;
		}
	}
}

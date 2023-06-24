using System;

namespace GlitchyEngine.Math;

/**
 * Represents a 4 by 4 column-major matrix.
 */
[Union]
public struct Matrix
{
	public struct Values
	{
		public float _11, _21, _31, _41,
					_12, _22, _32, _42,
					_13, _23, _33, _43,
					_14, _24, _34, _44;
	}

	public const Matrix Zero = .();
	public const Matrix Identity = .(.UnitX, .UnitY, .UnitZ, .UnitW);

	public using Values V;
	public float[4][4] Values;
	public float4[4] Columns;
	
	/// Creates a new zero-matrix.
	public this() => this = default;

	/**
	 * Initializes a new Matrix.
	 * @param value The value that will be assigned to all components.
	 */
	/// Creates a new matrix.
	public this(float value)
	{
		this = ?;
		_11 = _12 = _13 = _14 =
		_21 = _22 = _23 = _24 =
		_31 = _32 = _33 = _34 =
		_41 = _42 = _43 = _44 = value;
	}

	/// Creates a new matrix and initializes it with the given entries.
	public this(float m00, float m01, float m02, float m03,
	         	float m10, float m11, float m12, float m13,
	         	float m20, float m21, float m22, float m23,
			 	float m30, float m31, float m32, float m33)
	{
		Values[0][0] = m00; Values[0][1] = m10; Values[0][2] = m20; Values[0][3] = m30;
		Values[1][0] = m01; Values[1][1] = m11; Values[1][2] = m21; Values[1][3] = m31;
		Values[2][0] = m02; Values[2][1] = m12; Values[2][2] = m22; Values[2][3] = m32;
		Values[3][0] = m03; Values[3][1] = m13; Values[3][2] = m23; Values[3][3] = m33;
	}

	/// Creates a new matrix and initializes it with the given column-vectors.
	public this(float4 c0, float4 c1, float4 c2, float4 c3)
	{
		Columns[0] = c0;
		Columns[1] = c1;
		Columns[2] = c2;
		Columns[3] = c3;
	}

	public ref float3 Right
	{
		[Inline]
		get
		{
#unwarn
			return ref *(float3*)&Columns[0];
		}
	}

	public ref float3 Up
	{
		[Inline]
		get
		{
#unwarn
			return ref *(float3*)&Columns[1];
		}
	}

	public ref float3 Forward
	{
		[Inline]
		get
		{
#unwarn
			return ref *(float3*)&Columns[2];
		}
	}

	public ref float3 Translation
	{
		[Inline]
		get
		{
#unwarn
			return ref *(float3*)&Columns[3];
		}
	}

	public float3 Scale
	{
		[Inline]
		get => .(_11, _22, _33);

		[Inline]
		set mut
		{
			_11 = value.X;
			_22 = value.Y;
			_33 = value.Z;
		}
	}

	public ref float this[int row, int column]
	{
		get
		{
#unwarn
			return ref *(float*)&Values[column][row];
		}

		[Checked]
		get
		{
			if(column < 0 || column > 3 || row < 0 || row > 3)
				Internal.ThrowIndexOutOfRange();
			
#unwarn
			return ref *(float*)&Values[column][row];
		}
	}
	
	public ref float4 this[int column]
	{
		get
		{
#unwarn
			return ref *(float4*)&Columns[column];
		}

		
		[Checked]
		get
		{
			if(column < 0 || column > 3)
				Internal.ThrowIndexOutOfRange();
			
#unwarn
			return ref *(float4*)&Columns[column];
		}
	}

	//
	// Assignment Operators
	//

	// Addition

	public void operator +=(Matrix value) mut
	{	
		Columns[0] += value.Columns[0];
		Columns[1] += value.Columns[1];
		Columns[2] += value.Columns[2];
		Columns[3] += value.Columns[3];
	}

	// Matrix + Scalar : Matrix + Scalar * Identity
	public void operator +=(float scalar) mut
	{
		_11 += scalar;
		_22 += scalar;
		_33 += scalar;
		_44 += scalar;
	}

	// Subtraction

	public void operator -=(Matrix value) mut
	{	
		Columns[0] -= value.Columns[0];
		Columns[1] -= value.Columns[1];
		Columns[2] -= value.Columns[2];
		Columns[3] -= value.Columns[3];
	}

	// Matrix - Scalar : Matrix - Scalar * Identity
	public void operator -=(float scalar) mut
	{
		_11 -= scalar;
		_22 -= scalar;
		_33 -= scalar;
		_44 -= scalar;
	}

	// Multiplication

	public void operator *=(float scalar) mut
	{	
		Columns[0] *= scalar;
		Columns[1] *= scalar;
		Columns[2] *= scalar;
		Columns[3] *= scalar;
	}
	
	public void operator *=(Matrix value) mut
	{
		this = this * value;
	}

	// Divide

	public void operator /=(float scalar) mut
	{
		float inv = 1.0f / scalar;
		Columns[0] *= inv;
		Columns[1] *= inv;
		Columns[2] *= inv;
		Columns[3] *= inv;
	}

	//
	// Operators
	//

	// Addition
	
	public static Matrix operator +(Matrix left, Matrix right)
	{
		return .(left.Columns[0] + right.Columns[0],
				left.Columns[1] + right.Columns[1],
				left.Columns[2] + right.Columns[2],
				left.Columns[3] + right.Columns[3]);
	}

	public static Matrix operator +(Matrix left, float right)
	{
		Matrix result = left;
		result._11 += right;
		result._22 += right;
		result._33 += right;
		result._44 += right;

		return result;
	}
	
	public static Matrix operator +(float left, Matrix right)
	{
		Matrix result = right;
		result._11 += left;
		result._22 += left;
		result._33 += left;
		result._44 += left;

		return result;
	}

	// Subtraction
	
	public static Matrix operator -(Matrix left, Matrix right)
	{
		return .(left.Columns[0] - right.Columns[0],
				left.Columns[1] - right.Columns[1],
				left.Columns[2] - right.Columns[2],
				left.Columns[3] - right.Columns[3]);
	}

	public static Matrix operator -(Matrix value, float scalar)
	{
		Matrix result = value;
		result._11 -= scalar;
		result._22 -= scalar;
		result._33 -= scalar;
		result._44 -= scalar;

		return result;
	}

	public static Matrix operator -(float scalar, Matrix value)
	{
		Matrix result = value;
		result._11 -= scalar;
		result._22 -= scalar;
		result._33 -= scalar;
		result._44 -= scalar;

		return result;
	}

	public static Matrix operator -(Matrix value)
	{
		return .(-value.Columns[0],
				-value.Columns[1],
				-value.Columns[2],
				-value.Columns[3]);
	}

	// Multiplication

	public static Matrix operator *(Matrix left, Matrix right)
	{
#unwarn
		var l = &left.V;
#unwarn
		var r = &right.V;
		
		Matrix result = ?;

		result._11 = (l._11 * r._11) + (l._12 * r._21) + (l._13 * r._31) + (l._14 * r._41);
		result._12 = (l._11 * r._12) + (l._12 * r._22) + (l._13 * r._32) + (l._14 * r._42);
		result._13 = (l._11 * r._13) + (l._12 * r._23) + (l._13 * r._33) + (l._14 * r._43);
		result._14 = (l._11 * r._14) + (l._12 * r._24) + (l._13 * r._34) + (l._14 * r._44);
		
		result._21 = (l._21 * r._11) + (l._22 * r._21) + (l._23 * r._31) + (l._24 * r._41);
		result._22 = (l._21 * r._12) + (l._22 * r._22) + (l._23 * r._32) + (l._24 * r._42);
		result._23 = (l._21 * r._13) + (l._22 * r._23) + (l._23 * r._33) + (l._24 * r._43);
		result._24 = (l._21 * r._14) + (l._22 * r._24) + (l._23 * r._34) + (l._24 * r._44);
		
		result._31 = (l._31 * r._11) + (l._32 * r._21) + (l._33 * r._31) + (l._34 * r._41);
		result._32 = (l._31 * r._12) + (l._32 * r._22) + (l._33 * r._32) + (l._34 * r._42);
		result._33 = (l._31 * r._13) + (l._32 * r._23) + (l._33 * r._33) + (l._34 * r._43);
		result._34 = (l._31 * r._14) + (l._32 * r._24) + (l._33 * r._34) + (l._34 * r._44);
		
		result._41 = (l._41 * r._11) + (l._42 * r._21) + (l._43 * r._31) + (l._44 * r._41);
		result._42 = (l._41 * r._12) + (l._42 * r._22) + (l._43 * r._32) + (l._44 * r._42);
		result._43 = (l._41 * r._13) + (l._42 * r._23) + (l._43 * r._33) + (l._44 * r._43);
		result._44 = (l._41 * r._14) + (l._42 * r._24) + (l._43 * r._34) + (l._44 * r._44);

		return result;
	}

	public static Matrix operator *(Matrix value, float scalar)
	{
		return .(value.Columns[0] * scalar,
				value.Columns[1] * scalar,
				value.Columns[2] * scalar,
				value.Columns[3] * scalar);
	}
	
	public static Matrix operator *(float scalar, Matrix value)
	{
		return .(value.Columns[0] * scalar,
				value.Columns[1] * scalar,
				value.Columns[2] * scalar,
				value.Columns[3] * scalar);
	}

	/**
	 * Multiplies a matrix and a column-vector resulting in a column vector.
	 */
	public static float4 operator *(Matrix matrix, float4 columnVector)
	{
#unwarn
		var m = &matrix.V;

		float4 result = ?;
		result.X = (m._11 * columnVector.X) + (m._12 * columnVector.Y) + (m._13 * columnVector.Z) + (m._14 * columnVector.W);
		result.Y = (m._21 * columnVector.X) + (m._22 * columnVector.Y) + (m._23 * columnVector.Z) + (m._24 * columnVector.W);
		result.Z = (m._31 * columnVector.X) + (m._32 * columnVector.Y) + (m._33 * columnVector.Z) + (m._34 * columnVector.W);
		result.W = (m._41 * columnVector.X) + (m._42 * columnVector.Y) + (m._43 * columnVector.Z) + (m._44 * columnVector.W);
		return result;
	}
	
	/**
	 * Multiplies a row-vector and a matrix resulting in a row vector.
	 */
	public static float4 operator *(float4 rowVector, Matrix matrix)
	{
#unwarn
		var m = &matrix.V;

		float4 result = ?;
		result.X = (rowVector.X * m._11) + (rowVector.Y * m._21) + (rowVector.Z * m._31) + (rowVector.W * m._41);
		result.Y = (rowVector.X * m._12) + (rowVector.Y * m._22) + (rowVector.Z * m._32) + (rowVector.W * m._42);
		result.Z = (rowVector.X * m._13) + (rowVector.Y * m._23) + (rowVector.Z * m._33) + (rowVector.W * m._43);
		result.W = (rowVector.X * m._14) + (rowVector.Y * m._24) + (rowVector.Z * m._34) + (rowVector.W * m._44);
		return result;
	}

	// Divison

	public static Matrix operator /(Matrix m, float s)
	{
		float f = 1 / s;
		Matrix M = m;

		return .(M.Columns[0] * f, M.Columns[1] * f, M.Columns[2] * f, M.Columns[3] * f);
	}

	public static Matrix Scaling(float scale)
	{
		return .(scale, 0, 0, 0,
				 0, scale, 0, 0,
				 0, 0, scale, 0,
				 0, 0, 0, 1);
	}
	
	public static Matrix Scaling(float scaleX, float scaleY, float scaleZ)
	{
		return .(scaleX, 0, 0, 0,
				 0, scaleY, 0, 0,
				 0, 0, scaleZ, 0,
				 0, 0, 0, 1);
	}

	public static Matrix Scaling(float3 scale)
	{
		return .(scale.X, 0, 0, 0,
				 0, scale.Y, 0, 0,
				 0, 0, scale.Z, 0,
				 0, 0, 0, 1);
	}

	public static Matrix Translation(float x, float y, float z)
	{
		return .(1, 0, 0, x,
				 0, 1, 0, y,
				 0, 0, 1, z,
				 0, 0, 0, 1);
	}

	public static Matrix Translation(float3 translation)
	{
		return .(1, 0, 0, translation.X,
				 0, 1, 0, translation.Y,
				 0, 0, 1, translation.Z,
				 0, 0, 0, 1);
	}

	public static Matrix RotationX(float rot)
	{
		float sin = Math.Sin(rot);
		float cos = Math.Cos(rot);

		return .(1,  0,   0,   0,
				 0, cos, -sin, 0,
				 0, sin, cos,  0,
				 0,  0,   0,   1);
	}

	public static Matrix RotationY(float rot)
	{
		float sin = Math.Sin(rot);
		float cos = Math.Cos(rot);

		return .(cos, 0, sin, 0,
				  0,  1,  0,  0,
				-sin, 0, cos, 0,
				  0,  0,  0,  1);
	}

	public static Matrix RotationZ(float rot)
	{
		float sin = Math.Sin(rot);
		float cos = Math.Cos(rot);

		return .(cos, -sin, 0, 0,
				 sin,  cos, 0, 0,
				  0,    0,  1, 0,
				  0,    0,  0, 1);
	}

	/**
	 * Calculates a view Matrix that is located at specified postion and looks at the given target.
	 * @param position The cameras position.
	 * @param target The point the camera looks at.
	 * @param up A vector defining the up direction of the camera.
	 * @returns a view matrix.
	 */
	public static Matrix LookAt(float3 position, float3 target, float3 up)
	{
		float3 forward = normalize(target - position);

		float3 right = normalize(cross(up, forward));

		float3 newUp = normalize(cross(forward, right));

		Matrix result = .Identity;

		result.Forward = forward;
		result.Up = up;
		result.Right = right;
		result.Translation.X = -dot(position, right);
		result.Translation.Y = -dot(position, up);
		result.Translation.Z = -dot(position, forward);

		return result;
	}

	/// Returns the transpose of this matrix
	[DisableChecks]
	public Matrix Transpose()
	{
		return .(_11, _21, _31, _41,
				_12, _22, _32, _42,
				_13, _23, _33, _43,
				_14, _24, _34, _44);
	}

	/**
	Calculates the inverse of the matrix.
	*/
	[DisableChecks]
	public float Determinant() mut
	{
		// From: Lengyel, Eric. Foundations of Game Engine Development, Volume 1: Mathematics (S.61). Kindle-Version. 

		float3 a = *(float3*)&Columns[0];
		float3 b = *(float3*)&Columns[1];
		float3 c = *(float3*)&Columns[2]; 
		float3 d = *(float3*)&Columns[3];  

		float x = this[3, 0];
		float y = this[3, 1];
		float z = this[3, 2];
		float w = this[3, 3];

		float3 s = cross(a, b);
		float3 t = cross(c, d);
		float3 u = y * a - x * b;
		float3 v = w * c - z * d;

		return dot(s, v) + dot(t, u);
	}

	/**
	Calculates the inverse of the matrix.
	*/
	public Matrix Invert()
	{
		// From: Lengyel, Eric. Foundations of Game Engine Development, Volume 1: Mathematics (S.61). Kindle-Version. 

#unwarn
		float3 a = *(float3*)&Columns[0];
#unwarn
		float3 b = *(float3*)&Columns[1];
#unwarn
		float3 c = *(float3*)&Columns[2]; 
#unwarn
		float3 d = *(float3*)&Columns[3];  

		float x = this[3, 0];
		float y = this[3, 1];
		float z = this[3, 2];
		float w = this[3, 3];

		float3 s = cross(a, b);
		float3 t = cross(c, d);
		float3 u = y * a - x * b;
		float3 v = w * c - z * d;

		float invDet = 1.0f / (dot(s, v) + dot(t, u));

		s *= invDet;
		t *= invDet;
		u *= invDet;
		v *= invDet;

		float3 r0 = cross(b, v) + t * y;
		float3 r1 = cross(v, a) - t * x;
		float3 r2 = cross(d, u) + s * w;
		float3 r3 = cross(u, c) - s * z;
		return .(r0.X, r0.Y, r0.Z, -dot(b, t),
				 r1.X, r1.Y, r1.Z,  dot(a, t),
				 r2.X, r2.Y, r2.Z, -dot(d, s),
				 r3.X, r3.Y, r3.Z,  dot(c, s));
	}

	/// Calculates the inverse of the matrix.
	public static Matrix Invert(in Matrix matrix)
	{
		// From: Lengyel, Eric. Foundations of Game Engine Development, Volume 1: Mathematics (S.61). Kindle-Version. 
		
#unwarn
		float3 a = *(float3*)&matrix.Columns[0];
#unwarn
		float3 b = *(float3*)&matrix.Columns[1];
#unwarn
		float3 c = *(float3*)&matrix.Columns[2]; 
#unwarn
		float3 d = *(float3*)&matrix.Columns[3];  

		float x = matrix[3, 0];
		float y = matrix[3, 1];
		float z = matrix[3, 2];
		float w = matrix[3, 3];

		float3 s = cross(a, b);
		float3 t = cross(c, d);
		float3 u = y * a - x * b;
		float3 v = w * c - z * d;

		float invDet = 1.0f / (dot(s, v) + dot(t, u));

		s *= invDet;
		t *= invDet;
		u *= invDet;
		v *= invDet;

		float3 r0 = cross(b, v) + t * y;
		float3 r1 = cross(v, a) - t * x;
		float3 r2 = cross(d, u) + s * w;
		float3 r3 = cross(u, c) - s * z;
		return .(r0.X, r0.Y, r0.Z, -dot(b, t),
				 r1.X, r1.Y, r1.Z,  dot(a, t),
				 r2.X, r2.Y, r2.Z, -dot(d, s),
				 r3.X, r3.Y, r3.Z,  dot(c, s));
	}
	
	/**
	 * Creates a perspective projection matrix.
	 * @param fovY The vertical field of view.
	 * @param aspectRation The aspect ratio of the viewport.
	 * @param nearPlane The distance to the near plane.
	 * @param farPlane The distance to the far plane.
	 */
	public static Matrix PerspectiveProjection(float fovY, float aspectRatio, float nearPlane, float farPlane)
	{
		// Lengyel, Eric. Foundations of Game Engine Development, Volume 2: Rendering (Seite82).  . Kindle-Version. 

		float g = 1.0f / Math.Tan(fovY * 0.5f);
		float k = farPlane / (farPlane - nearPlane);

		return .(g / aspectRatio, 0, 0, 0,
				0, g, 0, 0,
				0, 0, k, -nearPlane * k,
				0, 0, 1, 0);
	}
	
	/**
	 * Creates a perspective projection matrix with reversed near- and far plane.
	 * (i.e. Points on near plane have z-value of 1 and points of far plane have z-value of 0)
	 * @param fovY The vertical field of view.
	 * @param aspectRation The aspect ratio of the viewport.
	 * @param nearPlane The distance to the near plane.
	 * @param farPlane The distance to the far plane.
	 */
	public static Matrix ReversedPerspectiveProjection(float fovY, float aspectRatio, float nearPlane, float farPlane)
	{
		// Lengyel, Eric. Foundations of Game Engine Development, Volume 2: Rendering (Seite86).  . Kindle-Version. 

		float g = 1.0f / Math.Tan(fovY * 0.5f);
		float k = nearPlane / (nearPlane - farPlane);

		return .(g / aspectRatio, 0, 0, 0,
				0, g, 0, 0,
				0, 0, k, -farPlane * k,
				0, 0, 1, 0);
	}

	/**
	 * Creates a perspective projection matrix with a far plane at infinity.
	 * @param fovY The vertical field of view.
	 * @param aspectRation The aspect ratio of the viewport.
	 * @param nearPlane The distance to the near plane.
	 * @param ε An offset to account for floating point round-off errors at infinity.
	 *			Note: Use a tiny value significant compared to the floating-point value of one.
	 */
	public static Matrix InfinitePerspectiveProjection(float fovY, float aspectRatio, float nearPlane, float ε = 1e-6f)
	{
		// Lengyel, Eric. Foundations of Game Engine Development, Volume 2: Rendering (Seite83).  . Kindle-Version.

		float g = 1.0f / Math.Tan(fovY * 0.5f);

		float f = 1 - ε;

		return .(g / aspectRatio, 0, 0, 0,
				0, g, 0, 0,
				0, 0, f, -nearPlane * f,
				0, 0, 1, 0);
	}
	
	/**
	 * Creates a perspective projection matrix with a far plane at infinity with reversed near- and far plane.
	 * (i.e. Points on near plane have z-value of 1 and points of far plane have z-value of 0)
	 * @param fovY The vertical field of view.
	 * @param aspectRation The aspect ratio of the viewport.
	 * @param nearPlane The distance to the near plane.
	 * @param ε An offset to account for floating point round-off errors at infinity.
	 *			Note: Use a tiny value significant compared to the floating-point value of one.
	 */
	public static Matrix ReversedInfinitePerspectiveProjection(float fovY, float aspectRatio, float nearPlane, float ε = 1e-6f)
	{
		// Lengyel, Eric. Foundations of Game Engine Development, Volume 2: Rendering (Seite88).  . Kindle-Version. 

		float g = 1.0f / Math.Tan(fovY * 0.5f);

		return .(g / aspectRatio, 0, 0, 0,
				0, g, 0, 0,
				0, 0, ε, nearPlane * (1 - ε),
				0, 0, 1, 0);
	}
	
	/**
	 * Creates an orthographic projection matrix with the camera centered at the near-plane.
	 * @param width The width of the view volume.
	 * @param height The height of the view volume.
	 * @param depth The depth of the view volume.
	 */
	public static Matrix OrthographicProjection(float width, float height, float depth)
	{
		// Lengyel, Eric. Foundations of Game Engine Development, Volume 2: Rendering (Seite91).  . Kindle-Version. 
		return .(2.0f / width, 0, 0, 0,
				0, 2.0f/height, 0, 0,
				0, 0, 1.0f / depth, 0,
				0, 0, 0, 1);
	}
	
	/**
	 * Creates an orthographic projection matrix.
	 * @param left The left side of the view volume.
	 * @param right The right side of the view volume.
	 * @param top The top side of the view volume.
	 * @param bottom The bottom side of the view volume.
	 * @param near The near plane of the view volume.
	 * @param far The far plane of the view volume.
	 */
	public static Matrix OrthographicProjectionOffCenter(float left, float right, float top, float bottom, float near, float far)
	{
		// Lengyel, Eric. Foundations of Game Engine Development, Volume 2: Rendering (Seite91).  . Kindle-Version.

		float w_inv = 1.0f / (right - left);
		float h_inv = 1.0f / (top - bottom);
		float d_inv = 1.0f / (far - near);

		return .(2.0f * w_inv,	0.0f, 	  0.0f, -(right + left) * w_inv,
					0.0f,	2.0f * h_inv, 0.0f, -(bottom + top) * h_inv,
					0.0f, 		0.0f,     d_inv, 	-near * d_inv,
					0.0f, 		0.0f, 	  0.0f, 		1.0f);
	}

	public static bool operator ==(Matrix left, Matrix right)
	{
		return Matrix.Equals(left, right);
	}
	
	public static bool operator !=(Matrix left, Matrix right)
	{
		return !Matrix.Equals(left, right);
	}

	public static bool Equals(Matrix left, Matrix right)
	{
		return left.Values == right.Values;
	}

	public static explicit operator Matrix3x3(Matrix value)
	{
		return .(value.Right, value.Up, value.Forward);
	}

	public static void Exponent(ref Matrix matrix, int exponent, out Matrix result)
	{
		if(exponent == 0)
			result = .Identity;
		else if(exponent == 1)
			result = matrix;
		else if(exponent > 1)
		{
			result = .Identity;
			Matrix b = matrix;

			var exponent;

			for(;exponent > 0;)
			{
				if(exponent & 1 > 0)
					result *= b;

				exponent >>= 1;

				if(exponent > 0)
					b *= b;
			}

		}
		else // Exponent < 0
		{
			Matrix m = matrix.Invert();
			Exponent(ref m, -exponent, out result);
		}
	}
	
	/**
	 * Orthogonalizes the matrix.
	*/
	public void Orthogonalize() mut
	{
		Columns[1] -= project(Columns[1], Columns[0]);
		Columns[2] -= project(Columns[2], Columns[0]) + project(Columns[2], Columns[1]);
		Columns[3] -= project(Columns[3], Columns[0]) + project(Columns[3], Columns[1]) + project(Columns[3], Columns[2]);
	}

	/**
	 * Orthonormalizes the matrix.
	*/
	public void Orthonormalize() mut
	{
		Columns[0] = normalize(Columns[0]);
		Columns[1] = normalize(reject(Columns[1], Columns[0]));
		Columns[2] = normalize(reject(reject(Columns[2], Columns[0]), Columns[1]));
		Columns[3] = normalize(reject(reject(reject(Columns[2], Columns[0]), Columns[1]), Columns[2]));
	}
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

		result._11 = 1 - ySq - zSq;
		result._21 = xy + zw;
		result._31 = xz - yw;
		result._41 = 0;

		result._12 = xy - zw;
		result._22 = 1 - xSq - zSq;
		result._32 = yz + xw;
		result._42 = 0;

		result._13 = xz + yw;
		result._23 = yz - xw;
		result._33 = 1 - xSq - ySq;
		result._43 = 0;

		result._14 = 0;
		result._24 = 0;
		result._34 = 0;
		result._44 = 1;
		
		return result;
	}

	public static void Decompose(Self matrix, out float3 position, out Quaternion rotation, out float3 scale)
	{
		var matrix;

		// Translation -> get last column
		position = matrix.Translation;
		// Zero translation for next step
		matrix.Translation = .Zero;

		// TODO: this doesn't detect mirroring

		// Extract scaling from matrix
		scale.X = length(*(float3*)&matrix.Columns[0]);
		scale.Y = length(*(float3*)&matrix.Columns[1]);
		scale.Z = length(*(float3*)&matrix.Columns[2]);

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
}

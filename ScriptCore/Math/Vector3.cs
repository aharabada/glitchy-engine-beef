using System;
using System.CodeDom;
using System.Runtime.CompilerServices;

namespace GlitchyEngine.Math;

public struct Vector3
{
    public static readonly Vector3 Zero = new(0.0f, 0.0f, 0.0f);
    public static readonly Vector3 UnitX = new(1.0f, 0.0f, 0.0f);
    public static readonly Vector3 UnitY = new(0.0f, 1.0f, 0.0f);
    public static readonly Vector3 UnitZ = new(0.0f, 0.0f, 1.0f);
    public static readonly Vector3 One = new(0.0f, 0.0f, 0.0f);

    public static readonly Vector3 Forward = new(0.0f, 0.0f, 1.0f);
    public static readonly Vector3 Backward = new(0.0f, 0.0f, -1.0f);
    public static readonly Vector3 Left = new(-1.0f, 0.0f, 0.0f);
    public static readonly Vector3 Right = new(1.0f, 0.0f, 0.0f);
    public static readonly Vector3 Up = new(0.0f, 1.0f, 0.0f);
    public static readonly Vector3 Down = new(0.0f, -1.0f, 0.0f);

    public const int ComponentCount = 3;

    public float X, Y, Z;

    public Vector3()
    {
        X = Y = Z = 0.0f;
    }

    public Vector3(float x, float y, float z)
    {
        X = x;
        Y = y;
        Z = z;
    }
    public Vector3(Vector2 xy, float z)
    {
        X = xy.X;
        Y = xy.Y;
        Z = z;
    }

    public float this[int index]
    {
        get
        {
            switch(index)
            {
                case 0: return X;
                case 1: return Y;
                case 2: return Z;
                default: throw new IndexOutOfRangeException();
            }
        }

        set
        {
            switch(index)
            {
                case 0:
                    X = value;
                    break;
                case 1:
                    Y = value;
                    break;
                case 2:
                    Z = value;
                    break;
                default: throw new IndexOutOfRangeException();
            }
        }
    }
    
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator +(in Vector3 a, in Vector3 b) => new(a.X + b.X, a.Y + b.Y, a.Z + b.Z);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator +(float a, in Vector3 b) => new(a + b.X, a + b.Y, a + b.Z);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator +(in Vector3 a, float b) => new(a.X + b, a.Y + b, a.Z + b);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator +(in Vector3 a) => a;
    
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator -(in Vector3 a, in Vector3 b) => new(a.X - b.X, a.Y - b.Y, a.Z - b.Z);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator -(float a, in Vector3 b) => new(a - b.X, a - b.Y, a - b.Z);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator -(in Vector3 a, float b) => new(a.X - b, a.Y - b, a.Z - b);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator -(in Vector3 a) => new Vector3(-a.X, -a.Y, -a.Z);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator *(in Vector3 a, in Vector3 b) => new(a.X * b.X, a.Y * b.Y, a.Z * b.Z);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator *(float a, in Vector3 b) => new(a * b.X, a * b.Y, a * b.Z);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator *(in Vector3 a, float b) => new(a.X * b, a.Y * b, a.Z * b);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator /(in Vector3 a, in Vector3 b) => new(a.X / b.X, a.Y / b.Y, a.Z / b.Z);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator /(float a, in Vector3 b) => new(a / b.X, a / b.Y, a / b.Z);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector3 operator /(in Vector3 a, float b) => new(a.X / b, a.Y / b, a.Z / b);

    
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static bool operator ==(Vector3 a, Vector3 b)
    {
        float diffX = a.X - b.X;
        float diffY = a.Y - b.Y;
        float diffZ = a.Z - b.Z;

        return diffX * diffX + diffY * diffY + diffZ * diffZ < 0.00001f;
    }
    
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static bool operator !=(Vector3 a, Vector3 b)
    {
        return !(a == b);
    }
    
    public override int GetHashCode()
    {
        unchecked
        {
            var hashCode = X.GetHashCode();
            hashCode = (hashCode * 397) ^ Y.GetHashCode();
            hashCode = (hashCode * 397) ^ Z.GetHashCode();
            return hashCode;
        }
    }
    
    public override string ToString()
    {
        return $"X:{X}, Y:{Y}, Z:{Z}";
    }
}
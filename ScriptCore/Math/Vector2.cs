using System;
using System.Runtime.CompilerServices;

namespace GlitchyEngine.Math;

public struct Vector2
{
    public static readonly Vector2 Zero = new(0.0f, 0.0f);
    public static readonly Vector2 UnitX = new(1.0f, 0.0f);
    public static readonly Vector2 UnitY = new(0.0f, 1.0f);
    public static readonly Vector2 One = new(0.0f, 0.0f);
    
    public const int ComponentCount = 2;

    public float X, Y;

    public Vector2()
    {
        X = Y = 0.0f;
    }

    public Vector2(float x, float y)
    {
        X = x;
        Y = y;
    }

    public float this[int index]
    {
        get
        {
            switch(index)
            {
                case 0: return X;
                case 1: return Y;
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
                default: throw new IndexOutOfRangeException();
            }
        }
    }
    
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator +(in Vector2 a, in Vector2 b) => new(a.X + b.X, a.Y + b.Y);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator +(float a, in Vector2 b) => new(a + b.X, a + b.Y);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator +(in Vector2 a, float b) => new(a.X + b, a.Y + b);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator +(in Vector2 a) => a;
    
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator -(in Vector2 a, in Vector2 b) => new(a.X - b.X, a.Y - b.Y);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator -(float a, in Vector2 b) => new(a - b.X, a - b.Y);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator -(in Vector2 a, float b) => new(a.X - b, a.Y - b);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator -(in Vector2 a) => new Vector2(-a.X, -a.Y);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator *(in Vector2 a, in Vector2 b) => new(a.X * b.X, a.Y * b.Y);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator *(float a, in Vector2 b) => new(a * b.X, a * b.Y);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator *(in Vector2 a, float b) => new(a.X * b, a.Y * b);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator /(in Vector2 a, in Vector2 b) => new(a.X / b.X, a.Y / b.Y);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator /(float a, in Vector2 b) => new(a / b.X, a / b.Y);
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static Vector2 operator /(in Vector2 a, float b) => new(a.X / b, a.Y / b);

    
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static bool operator ==(Vector2 a, Vector2 b)
    {
        float diffX = a.X - b.X;
        float diffY = a.Y - b.Y;

        return diffX * diffX + diffY * diffY < 0.00001f;
    }
    
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static bool operator !=(Vector2 a, Vector2 b)
    {
        return !(a == b);
    }

    public float Length()
    {
        return (float)System.Math.Sqrt(X * X + Y * Y);
    }

    public override int GetHashCode()
    {
        unchecked
        {
            var hashCode = X.GetHashCode();
            hashCode = (hashCode * 397) ^ Y.GetHashCode();
            return hashCode;
        }
    }
    
    public override string ToString()
    {
        return $"X:{X}, Y:{Y}";
    }
}
using System;

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
}
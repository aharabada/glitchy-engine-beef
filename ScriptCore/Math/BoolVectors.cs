using System;
using GlitchyEngine.Math;
using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

[Vector(typeof(bool), 2, "bool")]
[VectorLogic]
public partial struct bool2
{
    public static bool2 operator !(bool2 value)
    {
        return new bool2(!value.X, !value.Y);
    }
}

[Vector(typeof(bool), 3, "bool")]
[VectorLogic]
public partial struct bool3
{
    public static bool3 operator !(bool3 value)
    {
        return new bool3(!value.X, !value.Y, !value.Z);
    }
}

[Vector(typeof(bool), 4, "bool")]
[VectorLogic]
public partial struct bool4
{
    public static bool4 operator !(bool4 value)
    {
        return new bool4(!value.X, !value.Y, !value.Z, !value.W);
    }
}

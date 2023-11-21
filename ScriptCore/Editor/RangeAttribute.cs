using System;

namespace GlitchyEngine.Editor;

public sealed class RangeAttribute : Attribute
{
    public double Min { get; set; }
    public double Max { get; set; }

    public RangeAttribute(double min, double max)
    {
        if (max < min)
            throw new ArgumentOutOfRangeException(nameof(max), $"{nameof(max)} must be larger than {nameof(min)}.");

        Min = min;
        Max = max;
    }
}
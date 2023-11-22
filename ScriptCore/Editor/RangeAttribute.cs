using System;

namespace GlitchyEngine.Editor;

/// <summary>
/// Specifies a minimum and maximum value that can be set using the editor for the field.
/// </summary>
/// <remarks>
/// This only affects the editor. The range does <b>not</b> affect scripts changing the value of the field.
/// </remarks>
[AttributeUsage(AttributeTargets.Field)]
public sealed class RangeAttribute : Attribute
{
    /// <summary>
    /// The minimum value that can be assigned to the field using the editor.
    /// </summary>
    public double Min { get; private set; }
    
    /// <summary>
    /// The maximum value that can be assigned to the field using the editor.
    /// </summary>
    public double Max { get; private set; }
    
    /// <summary>
    /// The speed with which the value will be changed when dragging in the editor.
    /// </summary>
    public float Speed { get; private set; }

    /// <summary>
    /// If set to <see langword="true"/>, the editor field will be a slider instead of a number field.
    /// </summary>
    public bool Slider { get; private set; }


    /// <summary>
    /// Initializes a new instance of the <see cref="RangeAttribute"/> with a minimum, maximum value and optionally a speed.
    /// </summary>
    /// <param name="min"><inheritdoc cref="Min"/></param>
    /// <param name="max"><inheritdoc cref="Max"/></param>
    /// <param name="speed"><inheritdoc cref="Speed"/></param>
    public RangeAttribute(double min, double max, float speed = 1.0f, bool slider = false)
    {
        if (max < min)
            throw new ArgumentOutOfRangeException(nameof(max), $"{nameof(max)} must be larger than {nameof(min)}.");

        if (speed <= 0)
            throw new ArgumentOutOfRangeException(nameof(speed), $"{nameof(speed)} must be larger than zero.");

        Min = min;
        Max = max;
        Speed = speed;
        Slider = slider;
    }
}

/// <summary>
/// Specifies a minimum value that can be set using the editor for the field.
/// </summary>
/// <remarks>
/// If the field also has a <see cref="RangeAttribute"/>, the <see cref="RangeAttribute"/> takes precedence.
/// <br/><br/>
/// If the field also has a <see cref="MaximumAttribute"/>, and <see cref="Min"/> is larger than <see cref="MaximumAttribute.Max"/>, then no range will be applied.
/// <br/><br/>
/// The value specified only affects the editor. It does <b>not</b> affect scripts changing the value of the field.
/// </remarks>
[AttributeUsage(AttributeTargets.Field)]
public sealed class MinimumAttribute : Attribute
{
    /// <summary>
    /// The minimum value that can be assigned to the field using the editor.
    /// </summary>
    public double Min { get; private set; }

    /// <summary>
    /// Initializes a new instance of the <see cref="RangeAttribute"/> with a minimum value.
    /// </summary>
    /// <param name="min"><inheritdoc cref="Min"/></param>
    public MinimumAttribute(double min)
    {
        Min = min;
    }
}


/// <summary>
/// Specifies a maximum value that can be set using the editor for the field.
/// </summary>
/// <remarks>
/// If the field also has a <see cref="RangeAttribute"/>, the <see cref="RangeAttribute"/> takes precedence.
/// <br/><br/>
/// If the field also has a <see cref="MinimumAttribute"/>, and <see cref="MinimumAttribute.Min"/> is larger than <see cref="Max"/>, then no range will be applied.
/// <br/><br/>
/// The value specified only affects the editor. It does <b>not</b> affect scripts changing the value of the field.
/// </remarks>
[AttributeUsage(AttributeTargets.Field)]
public sealed class MaximumAttribute : Attribute
{
    /// <summary>
    /// The maximum value that can be assigned to the field using the editor.
    /// </summary>
    public double Max { get; private set; }

    /// <summary>
    /// Initializes a new instance of the <see cref="RangeAttribute"/> with a maximum value.
    /// </summary>
    /// <param name="max"><inheritdoc cref="Max"/></param>
    public MaximumAttribute(double max)
    {
        Max = max;
    }
} 
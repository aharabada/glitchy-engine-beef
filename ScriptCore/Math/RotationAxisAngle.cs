using System.Runtime.InteropServices;

namespace GlitchyEngine.Math;

/// <summary>
/// Represents a rotation around an axis by a specific angle.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack=1)]
public struct RotationAxisAngle
{
    /// <summary>
    /// The axis around which the rotation is applied.
    /// </summary>
    public float3 Axis;
    /// <summary>
    /// The angle in radians around the <see cref="Axis"/>.
    /// </summary>
    public float Angle;

    /// <summary>
    /// Creates a new instance of an axis angle rotation.
    /// </summary>
    /// <param name="axis">The axis.</param>
    /// <param name="angle">The angle in radians.</param>
    public RotationAxisAngle(float3 axis, float angle)
    {
        Axis = axis;
        Angle = angle;
    }
}

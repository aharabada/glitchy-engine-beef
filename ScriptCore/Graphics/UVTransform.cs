using System.Runtime.InteropServices;
using GlitchyEngine.Math;

namespace GlitchyEngine.Graphics;

/// <summary>
/// Stores transformations that can be applied to UV-Coordinates.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack=1)]
public struct UVTransform
{
    /// <summary>
    /// The offset that will be added to the UV-Coordinate.
    /// </summary>
    public float2 Offset;
    /// <summary>
    /// The scaling that will be applied to the UV-Coordinate.
    /// </summary>
    public float2 Scale;

    /// <summary>
    /// Creates a new instance of <see cref="UVTransform"/> with the given scale and offset.
    /// </summary>
    /// <param name="offset"><inheritdoc cref="Offset"/></param>
    /// <param name="scale"><inheritdoc cref="Scale"/></param>
    public UVTransform(float2 offset, float2 scale)
    {
        Offset = offset;
        Scale = scale;
    }

    /// <summary>
    /// Transforms the given uv-coordinate.
    /// </summary>
    public float2 Transform(float2 uvCoordinate)
    {
        return Offset + uvCoordinate * Scale;
    }
}

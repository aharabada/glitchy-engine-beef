using System.Runtime.InteropServices;

namespace MarshallingBench;

/// <summary>
/// Mirrors <c>BeefDemoLib.Vec3</c> ([CRepr]). Lives in this assembly only because both assemblies need it.
/// </summary>
[StructLayout(LayoutKind.Sequential)]
public struct Vec3(float x, float y, float z)
{
    public float X = x;
    public float Y = y;
    public float Z = z;

    public override readonly string ToString() => $"({X}, {Y}, {Z})";
}

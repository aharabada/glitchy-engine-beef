using System;

namespace BeefDemoLib;

[CRepr]
public struct Vec3
{
	public float X;
	public float Y;
	public float Z;
}

/// Exported functions for the marshalling benchmark.
/// The bodies are intentionally trivial so that the cost of the managed -> native transition dominates.
static class Exports
{
	[Export, LinkName("Bench_AddInt"), CallingConvention(.Cdecl)]
	public static int32 AddInt(int32 a, int32 b) => a + b;

	[Export, LinkName("Bench_IsGreater"), CallingConvention(.Cdecl)]
	public static bool IsGreater(int32 a, int32 b) => a > b;

	[Export, LinkName("Bench_Scale"), CallingConvention(.Cdecl)]
	public static void Scale(in Vec3 v, float s, out Vec3 result)
	{
		result.X = v.X * s;
		result.Y = v.Y * s;
		result.Z = v.Z * s;
	}

	[Export, LinkName("Bench_Length"), CallingConvention(.Cdecl)]
	public static float Length(in Vec3 v) => Math.Sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z);
}

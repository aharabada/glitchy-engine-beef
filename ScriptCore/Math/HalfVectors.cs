using System;
using GlitchyEngine.Math.Attributes;

namespace GlitchyEngine.Math;

[Vector(typeof(Half), 2, "half")]
[VectorCast(typeof(float2), true)]
public partial struct half2
{
}

[Vector(typeof(Half), 3, "half")]
[VectorCast(typeof(float3), true)]
public partial struct half3
{
}

[Vector(typeof(Half), 4, "half")]
[VectorCast(typeof(float4), true)]
public partial struct half4
{
}

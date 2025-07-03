using Bon;
using System;

namespace GlitchyEngine.Math;

[BonTarget, CRepr]
[Vector<bool, 2>]
[SwizzleVector(2, "GlitchyEngine.Math.bool")]
struct bool2
{

}

[BonTarget, CRepr]
[Vector<bool, 3>]
[SwizzleVector(3, "GlitchyEngine.Math.bool")]
[VectorConditionals<bool, 3>]
struct bool3
{

}

[BonTarget, CRepr]
[Vector<bool, 4>]
[SwizzleVector(4, "GlitchyEngine.Math.bool")]
[VectorConditionals<bool, 4>]
struct bool4
{

}
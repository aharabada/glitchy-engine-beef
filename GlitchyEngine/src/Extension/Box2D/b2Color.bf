using System;
using GlitchyEngine.Math;
namespace Box2D;

extension b2Color
{
	[Inline]
#unwarn
	public static explicit operator ColorRGBA(b2Color color) => ColorRGBA(color.r, color.g, color.b, color.a);
}

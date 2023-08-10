using System;
using GlitchyEngine.Core;

namespace GlitchyEngine.Scripting.Classes;

[Ordered, Packed]
struct Collision2D
{
	public UUID Entity;
	public UUID OtherEntity;

	public UUID Rigidbody;
	public UUID OtherRigidbody;
}

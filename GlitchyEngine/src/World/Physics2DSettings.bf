using GlitchyEngine.Math;
using System;

namespace GlitchyEngine.World;

struct Physics2DSettings
{
	private Scene _scene;

	[Inline]
	private Box2D.b2World* _physicsWorld => _scene.[Friend]_physicsWorld2D;

	public float2 _gravity = .(0.0f, -9.8f);
	
	public float2 Gravity
	{
		get => _gravity;
		set mut
		{
			if (all(_gravity == value))
				return;

			_gravity = value;

			if (_physicsWorld != null)
				Box2D.World.SetGravity(_physicsWorld, _gravity);
		}
	}

	public int32 VelocityIterations = 6;
	public int32 PositionIterations = 2;
	public int32 ParticleIterations = 2;

	public this(Scene scene)
	{
		_scene = scene;
	}
}

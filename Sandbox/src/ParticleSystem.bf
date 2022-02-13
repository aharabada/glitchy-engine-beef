using GlitchyEngine.Math;
using GlitchyEngine;
using System;
using GlitchyEngine.Renderer;
namespace Sandbox
{
	class ParticleSystem
	{
		struct Particle
		{
			public bool IsAlive;
			public Vector2 Position;
			public float Rotation;
			public float Scale;
			public Vector2 Velocity;
			public float AngularVelocity;
			public float LiveTime;
			public Color Color;
		}

		private Random _random = new .() ~ delete _;

		private Particle[] _particles ~ delete _;
		private int _freeParticles;

		public float EmissionRate;
		public float EmissionAngle;
		public Vector2 EmissionDirection;
		public float EmissionVelocity;

		public float EmissionSize;
		public float EmissionSizeVariance;

		public float LiveTime;
		public float LiveTimeVariance;

		public Vector2 Position;

		public bool Emit;

		public Color EmmisionColor = .White;

		public this(int maxParticles)
		{
			_particles = new Particle[maxParticles];
			_freeParticles = maxParticles;
		}

		private float _emission = 0.0f;

		public void Update(GameTime gameTime)
		{
			for (var particle in ref _particles)
			{
				if (!particle.IsAlive)
					continue;

				particle.LiveTime -= gameTime.DeltaTime;

				if (particle.LiveTime < 0.0f)
				{
					particle.IsAlive = false;
					_freeParticles++;
				}

				particle.Position += particle.Velocity * gameTime.DeltaTime;
				particle.Rotation += particle.AngularVelocity * gameTime.DeltaTime;
			}

			if (Emit)
			{
				_emission += gameTime.DeltaTime * EmissionRate;
	
				while (_emission >= 1.0f)
				{
					Emit();
	
					_emission--;
				}
			}
		}

		public void Draw()
		{
			for (let particle in _particles)
			{
				if(particle.IsAlive)
					Renderer2D.DrawQuad(particle.Position, .(particle.Scale), particle.Rotation, particle.Color);
			}
		}

		private Particle* GetFreeParticle()
		{
			for (ref Particle particle in ref _particles)
			{
				if (!particle.IsAlive)
					return &particle;
			}

			return null;
		}

		private void Emit()
		{
			if (_freeParticles == 0)
				return;

			Particle* particle = GetFreeParticle();

			if (particle == null)
				return;

			particle.IsAlive = true;
			particle.Position = Position;
			particle.Rotation = 0;
			particle.Scale = EmissionSize + (float)_random.NextDoubleSigned() * EmissionSizeVariance;

			float angle = Math.Atan2(EmissionDirection.Y, EmissionDirection.X);

			angle += (float)_random.NextDoubleSigned() * EmissionAngle;

			Vector2 direction = .(Math.Cos(angle), Math.Sin(angle));

			particle.Velocity = direction * EmissionVelocity;
			particle.AngularVelocity = 0;//EmissionVelocity;
			particle.LiveTime = LiveTime + (float)_random.NextDoubleSigned() * LiveTimeVariance;

			particle.Color = EmmisionColor;

			_freeParticles--;
		}
	}
}
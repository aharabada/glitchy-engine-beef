using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using GlitchyEngine;
using System;
using System.Collections;

namespace Sandbox
{
	class Rocket
	{
		Texture2D _rocketTexture ~ _?.ReleaseRef();

		private Vector2 _gravity = .(0, -9.81f);

		public float Power = 50;

		public float FlightSpeed = 2;

		private Vector2 _acceleration = .(0, 0);
		private Vector2 _speed;

		private Vector2 _position;
		private Vector2 _direction;

		private Line2D _rocketLine;

		private float _rotation = -MathHelper.PiOverTwo;

		public bool Dead;

		public bool Started = false;

		public List<Obstacle> Obstacles;

		public int Score = 0;

		public Vector2 Position => _position;
		public Vector2 Direction => _direction;

		ParticleSystem _particleSystem ~ delete _;

		public this()
		{
			_rocketTexture = new Texture2D("content/RocketGame/Rocket.dds");
			_rocketTexture.SamplerState = SamplerStateManager.PointClamp;

			_particleSystem = new ParticleSystem(1024)
			{
				LiveTime = 1.0f,
				LiveTimeVariance = 0.5f,
				Emit = true,
			};
		}

		public void Update(GameTime gameTime)
		{
			do
			{
				FlightSpeed = Dead ? 0.0f : 2.0f;
				
				if (Dead && Input.IsKeyPressing(Key.Space))
				{
					Dead = false;
					Started = false;
					_speed = .Zero;
					Score = 0;
				}
				else if (!Started)
				{
					_position = .Zero;
					
					if (Input.IsKeyPressing(Key.Space))
						Started = true;
					else
						break;
				}
	
				UpdatePosition(gameTime);
	
				if (Started)
					CheckDead();
			}
			
			UpdateParticles(gameTime);
		}

		private void UpdateParticles(GameTime gameTime)
		{
			
			_particleSystem.Position = Position - Direction * 0.4f;
			_particleSystem.EmissionDirection = -Direction;
			_particleSystem.EmissionVelocity = FlightSpeed * 2;
			_particleSystem.EmissionAngle = MathHelper.PiOverFour / 2;

			_particleSystem.Emit = !Dead;

			if (Input.IsKeyPressing(Key.Space))
			{
				_particleSystem.EmissionRate = 100;
				_particleSystem.EmissionSize = 0.125f;
				_particleSystem.EmissionSizeVariance = 0.025f;

				_particleSystem.EmmisionColor = .(255, 106, 0);
			}
			else if (Input.IsKeyReleasing(Key.Space))
			{
				_particleSystem.EmissionRate = 10;
				_particleSystem.EmissionSize = 0.075f;
				_particleSystem.EmissionSizeVariance = 0.025f;

				_particleSystem.EmmisionColor = .(140, 126, 93);
			}

			_particleSystem.Update(gameTime);

		}

		public void Draw()
		{
			_particleSystem.Draw();

			Renderer2D.DrawQuad(Vector3(_position, 5), .One, _rotation, _rocketTexture, .White);
		}

		private void UpdatePosition(GameTime gameTime)
		{
			_acceleration.Y = 0;

			if (!Dead && Input.IsKeyPressed(Key.Space))
			{
				_acceleration.Y += Power;
			}

			Vector2 newSpeed = _speed + (_acceleration + _gravity) * gameTime.DeltaTime;

			Vector2 newPosition = _position + newSpeed * gameTime.DeltaTime;

			_speed = newSpeed;
			_position = newPosition;
			
			float ang = Math.Atan2(_speed.Y, 5) - MathHelper.PiOverTwo;

			_rotation = ang;

			_direction = Vector2.Normalize(_speed + .(5, 0));
			_rocketLine = .(_position - _direction / 2.8f, _position + _direction / 2.4f);
		}

		const float worldBorder = 2.1f;

		private void CheckDead()
		{
			if (Math.Abs(_position.Y) >= worldBorder)
			{
				Dead = true;
				_speed.Y *= -0.8f;
				_position.Y = Math.Clamp(_position.Y, -worldBorder, worldBorder);
			}

			CheckObstacles();
		}

		private int scoreLine = -1;

		private void CheckObstacles()
		{
			for (Obstacle obs in Obstacles)
			{
				//const float f = Vector2.One.Magnitude();
				float f = Vector2.One.Magnitude();

				Vector2 center = obs.Position;
				
				Vector2 topCenter = center + .(0, obs.HoleSize);
				Vector2 topTip = topCenter - .(0, 2.5f * f);
				Vector2 topRight = topCenter - .(f, 0);
				Vector2 topLeft = topCenter + .(f, 0);
				
				Vector2 bottomCenter = center - .(0, obs.HoleSize);
				Vector2 bottomTip = bottomCenter + .(0, 2.5f * f);
				Vector2 bottomRight = bottomCenter - .(f, 0);
				Vector2 bottomLeft = bottomCenter + .(f, 0);

				Line2D bottomR = .(bottomTip, bottomRight);
				Line2D bottomL = .(bottomTip, bottomLeft);

				Line2D topR = .(topTip, topRight);
				Line2D topL = .(topTip, topLeft);

				if ((bottomR.Intersects(_rocketLine) case .Intersection) ||
					(bottomL.Intersects(_rocketLine) case .Intersection) ||
					(topR.Intersects(_rocketLine) case .Intersection) ||
					(topL.Intersects(_rocketLine) case .Intersection))
				{
					Dead = true;
				}

				if (!Dead)
				{
					if (Line2D(bottomTip, topTip).Intersects(_rocketLine) case .Intersection)
					{
						scoreLine = @obs.Index;
					}
					else if (scoreLine == @obs.Index)
					{
						Score++;
						scoreLine = -1;
					}
				}
			}
		}
	}
}
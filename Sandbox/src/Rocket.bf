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

		private float _rotation;

		private bool _dead;

		private bool _started = false;

		public List<Obstacle> Obstacles;

		public int Score = 0;

		public this()
		{
			_rocketTexture = new Texture2D("content/RocketGame/Rocket.dds");
			_rocketTexture.SamplerState = SamplerStateManager.PointClamp;
		}

		public void Update(GameTime gameTime)
		{
			FlightSpeed = _dead ? 0.0f : 2.0f;

			if (!_started)
			{
				_position = .Zero;
				
				if (Input.IsKeyPressed(Key.Space))
					_started = true;
				else
					return;
			}

			UpdatePosition(gameTime);

			CheckDead();
		}

		public void Draw()
		{
			Renderer2D.DrawQuad(_position, .One, _rotation, _rocketTexture, .White);

			CheckObstacles();
		}

		Line2D rocketLine;

		private void UpdatePosition(GameTime gameTime)
		{
			_acceleration.Y = 0;

			if (!_dead && Input.IsKeyPressed(Key.Space))
			{
				_acceleration.Y += Power;
			}

			Vector2 newSpeed = _speed + (_acceleration + _gravity) * gameTime.DeltaTime;

			Vector2 newPosition = _position + newSpeed * gameTime.DeltaTime;

			_speed = newSpeed;
			_position = newPosition;
			
			float ang = Math.Atan2(_speed.Y, 10) - MathHelper.PiOverTwo;

			_rotation = ang;

			Vector2 dir = Vector2.Normalize(_speed + .(10, 0));
			rocketLine = .(_position - dir / 2.8f, _position + dir / 2.4f);
		}

		const float worldBorder = 2.1f;

		private void CheckDead()
		{
			if (Math.Abs(_position.Y) >= worldBorder)
			{
				_dead = true;
				_speed.Y *= -0.8f;
				_position.Y = Math.Clamp(_position.Y, -worldBorder, worldBorder);
			}
		}

		private int scoreLine = -1;

		private void CheckObstacles()
		{
			for (Obstacle obs in Obstacles)
			{
				const float f = Vector2.One.Magnitude();

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

				if ((bottomR.Intersects(rocketLine) case .Intersection) ||
					(bottomL.Intersects(rocketLine) case .Intersection) ||
					(topR.Intersects(rocketLine) case .Intersection) ||
					(topL.Intersects(rocketLine) case .Intersection))
				{
					_dead = true;
				}

				if (!_dead)
				{
					if (Line2D(bottomTip, topTip).Intersects(rocketLine) case .Intersection)
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
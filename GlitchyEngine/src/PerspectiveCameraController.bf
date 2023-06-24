using System;
using GlitchyEngine.Events;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;

namespace GlitchyEngine
{
	/// A simple controller for a perspective camera
	public class PerspectiveCameraController
	{
		private PerspectiveCamera _camera ~ delete _;
		private float _aspectRatio;
		private float _fovY = Math.PI_f / 4;
		
		private float3 _cameraPosition;
		private float3 _cameraRotation;
		
		private float _cameraTranslationSpeed = 1.0f;
		private float _cameraRotationSpeedX = 0.001f;
		private float _cameraRotationSpeedY = 0.001f;

		public PerspectiveCamera Camera => _camera;

		public float TranslationSpeed
		{
			get => _cameraTranslationSpeed;
			set => _cameraTranslationSpeed = value;
		}

		public float2 RotationSpeed
		{
			get => .(_cameraRotationSpeedX, _cameraRotationSpeedY);
			set
			{
				_cameraRotationSpeedX = value.X;
				_cameraRotationSpeedY = value.Y;
			}
		}

		public float3 CameraPosition
		{
			get => _cameraPosition;
			set
			{
				_cameraPosition = value;

				UpdateCamera();
			}
		}
		
		public float3 CameraRotation
		{
			get => _cameraRotation;
			set
			{
				_cameraRotation = value;

				UpdateCamera();
			}
		}

		public float FovY
		{
			get => _fovY;
			set
			{
				_fovY = value;

				UpdateCamera();
			}
		}
		
		public float AspectRatio
		{
			get => _aspectRatio;
			set
			{
				_aspectRatio = value;

				UpdateCamera();
			}
		}

		public this(float aspectRatio)
		{
			Debug.Profiler.ProfileFunction!();

			_aspectRatio = aspectRatio;

			_camera = new PerspectiveCamera();
			_camera.ProjectionType = .Infinite;
			_camera.NearPlane = 0.01f;

			UpdateCamera();
		}
		
		public void Update(GameTime gameTime)
		{
			Debug.Profiler.ProfileFunction!();

			if(Application.Get().Window.IsActive)
			{
				float3 movement = .();

				if(Input.IsKeyPressed(Key.W))
				{
					movement.Z += 1;
				}
				if(Input.IsKeyPressed(Key.S))
				{
					movement.Z -= 1;
				}

				if(Input.IsKeyPressed(Key.A))
				{
					movement.X -= 1;
				}
				if(Input.IsKeyPressed(Key.D))
				{
					movement.X += 1;
				}
				
				if(Input.IsKeyPressed(Key.Space))
				{
					movement.Y += 1;
				}
				if(Input.IsKeyPressed(Key.Control))
				{
					movement.Y -= 1;
				}

				if(any(movement != .Zero))
					normalize(movement);

				movement *= (float)(gameTime.FrameTime.TotalSeconds) * _cameraTranslationSpeed;
				
				float4 delta = float4(movement, 1.0f) * _camera.View;

				_cameraPosition += float3(delta.X, delta.Y, delta.Z);
				//_cameraPosition += movement;

				// Camera rotation
				var mouseDelta = Input.GetMouseMovement();

				float rotY = mouseDelta.X * _cameraRotationSpeedX;
				float rotX = mouseDelta.Y * _cameraRotationSpeedY;

				_cameraRotation.X += rotX;
				_cameraRotation.Y += rotY;

				UpdateCamera();
			}
		}

		public void OnEvent(Event e)
		{
			Debug.Profiler.ProfileFunction!();

			EventDispatcher dispatcher = EventDispatcher(e);
			dispatcher.Dispatch<WindowResizeEvent>(scope => OnWindowResized);
		}

		private bool OnWindowResized(WindowResizeEvent e)
		{
			Debug.Profiler.ProfileFunction!();

			_aspectRatio = (float)e.Width / (float)e.Height;

			UpdateCamera();

			return false;
		}

		private void UpdateCamera()
		{
			Debug.Profiler.ProfileFunction!();

			_camera.AspectRatio = _aspectRatio;
			_camera.FovY = _fovY;
			_camera.Rotation = _cameraRotation;
			_camera.Position = _cameraPosition;

			_camera.Update();
		}
	}
}

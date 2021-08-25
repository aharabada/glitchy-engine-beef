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
		
		private Vector3 _cameraPosition;
		private Vector3 _cameraRotation;
		
		private float _cameraTranslationSpeed = 1.0f;
		private float _cameraRotationSpeedX = 0.001f;
		private float _cameraRotationSpeedY = 0.001f;

		public PerspectiveCamera Camera => _camera;

		public float TranslationSpeed
		{
			get => _cameraTranslationSpeed;
			set => _cameraTranslationSpeed = value;
		}

		public Vector2 RotationSpeed
		{
			get => .(_cameraRotationSpeedX, _cameraRotationSpeedY);
			set
			{
				_cameraRotationSpeedX = value.X;
				_cameraRotationSpeedY = value.Y;
			}
		}

		public Vector3 CameraPosition
		{
			get => _cameraPosition;
			set
			{
				_cameraPosition = value;

				UpdateCamera();
			}
		}
		
		public Vector3 CameraRotation
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
			_aspectRatio = aspectRatio;

			_camera = new PerspectiveCamera();
			_camera.ProjectionType = .Infinite;
			_camera.NearPlane = 0.01f;

			UpdateCamera();
		}
		
		public void Update(GameTime gameTime)
		{
			if(Application.Get().Window.IsActive)
			{
				Vector3 movement = .();

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

				if(movement != .Zero)
					movement.Normalize();

				movement *= (float)(gameTime.FrameTime.TotalSeconds) * _cameraTranslationSpeed;
				
				Vector4 delta = Vector4(movement, 1.0f) * _camera.View;

				_cameraPosition += Vector3(delta.X, delta.Y, delta.Z);
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
			EventDispatcher dispatcher = EventDispatcher(e);
			dispatcher.Dispatch<WindowResizeEvent>(scope => OnWindowResized);
		}

		private bool OnWindowResized(WindowResizeEvent e)
		{
			_aspectRatio = (float)e.Width / (float)e.Height;

			UpdateCamera();

			return false;
		}

		private void UpdateCamera()
		{
			_camera.AspectRatio = _aspectRatio;
			_camera.FovY = _fovY;
			_camera.Rotation = _cameraRotation;
			_camera.Position = _cameraPosition;

			_camera.Update();
		}
	}
}

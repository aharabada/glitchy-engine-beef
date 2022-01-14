using GlitchyEngine.Renderer;
using GlitchyEngine.Events;
using GlitchyEngine.Math;
using System;

namespace GlitchyEngine
{
	/// A simple controller for an orthographic camera
	public class OrthographicCameraController
	{
		private OrthographicCamera _camera ~ delete _;
		private float _aspectRatio;
		private float _zoomLevel = 1.0f;

		private bool _rotation;

		private Vector3 _cameraPosition;
		private float _cameraRotation;
		private float _cameraTranslationSpeed = 1.0f;
		private float _cameraRotationSpeed = 1.0f;

		public OrthographicCamera Camera => _camera;

		public this(float aspectRatio, bool rotation = false)
		{
			Debug.Profiler.ProfileFunction!();

			_aspectRatio = aspectRatio;
			_rotation = rotation;

			_camera = new OrthographicCamera();
			_camera.NearPlane = -10f;
			_camera.FarPlane = 10f;

			UpdateCamera();
		}

		public void Update(GameTime gameTime)
		{
			Debug.Profiler.ProfileFunction!();

			if(Application.Get().Window.IsActive)
			{
				Vector3 movement = .();

				if(Input.IsKeyPressed(Key.W))
				{
					movement.Y += 1;
				}
				if(Input.IsKeyPressed(Key.S))
				{
					movement.Y -= 1;
				}

				if(Input.IsKeyPressed(Key.A))
				{
					movement.X -= 1;
				}
				if(Input.IsKeyPressed(Key.D))
				{
					movement.X += 1;
				}

				if(movement != .Zero)
					movement.Normalize();

				movement *= (float)(gameTime.FrameTime.TotalSeconds) * _cameraTranslationSpeed * _zoomLevel;

				_cameraPosition += movement;

				if(_rotation)
				{
					if(Input.IsKeyPressed(Key.Q))
					{
						_cameraRotation += (float)(gameTime.FrameTime.TotalSeconds) * _cameraRotationSpeed;
					}
					if(Input.IsKeyPressed(Key.E))
					{
						_cameraRotation -= (float)(gameTime.FrameTime.TotalSeconds) * _cameraRotationSpeed;
					}
				}

				UpdateCamera();
			}
		}

		public void OnEvent(Event e)
		{
			Debug.Profiler.ProfileFunction!();

			EventDispatcher dispatcher = EventDispatcher(e);
			dispatcher.Dispatch<MouseScrolledEvent>(scope => OnMouseScrolled);
			dispatcher.Dispatch<WindowResizeEvent>(scope => OnWindowResized);
		}

		private bool OnMouseScrolled(MouseScrolledEvent e)
		{
			Debug.Profiler.ProfileFunction!();

			_zoomLevel -= e.YOffset * 0.25f;

			_zoomLevel = Math.Max(_zoomLevel, 0.25f);
			
			UpdateCamera();

			return false;
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

			_camera.Left = -_aspectRatio * _zoomLevel;
			_camera.Right = _aspectRatio * _zoomLevel;
			_camera.Top = _zoomLevel;
			_camera.Bottom = -_zoomLevel;
			_camera.Rotation = .(_camera.Rotation.X, _camera.Rotation.Y, _cameraRotation);
			_camera.Position = _cameraPosition;

			_camera.Update();
		}
	}
}

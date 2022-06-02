using GlitchyEngine;
using GlitchyEngine.Renderer;
using GlitchyEngine.Math;
using System;
using GlitchyEngine.Events;

namespace GlitchyEngine.World
{
	struct EditorCamera : Camera, IDisposable
	{
		private Vector3 _position;
		private Quaternion _rotation;

		private Vector3 _focalPosition = .Zero;
		private float _focalDistance = 5.0f;
		
		private float _cameraTranslationSpeed = 2.0f;
		private float _cameraRotationSpeedX = 0.001f;
		private float _cameraRotationSpeedY = 0.001f;
		private float _cameraFastFactor = 10f;

		private Matrix _view;

		private float _fovY;
		private float _nearPlane;
		private float _aspectRatio;

		private RenderTargetGroup _renderTarget = null;
		
		internal bool BindMouse;
		internal uint8 MouseCooldown;

		private bool _isAltMode = false;

		public Matrix View => _view;

		// Gets whether or not the camera is currently being moved.
		public bool InUse => BindMouse;

		public RenderTargetGroup RenderTarget
		{
			get => _renderTarget;
			set mut
			{
				if (_renderTarget == value)
					return;

				SetReference!(_renderTarget, value);
			}
		}

		public Vector3 Position
		{
			get => _position;
			set mut
			{
				if (_position == value)
					return;

				_position = value;
				UpdateView();
			}
		}

		public Quaternion Rotation
		{
			get => _rotation;
			set mut
			{
				if (_rotation == value)
					return;

				_rotation = value;
				UpdateView();
			}
		}
		
		public Vector3 RotationEuler
		{
			get => Quaternion.ToEulerAngles(_rotation);
			set mut
			{
				Quaternion quat = Quaternion.FromEulerAngles(value.Y, value.X, value.Z);
				if (_rotation == quat)
					return;

				_rotation = quat;
				UpdateView();
			}
		}
		
		public (Vector3 Axis, float Angle) RotationAxisAngle
		{
			get => _rotation.ToAxisAngle();
			set mut
			{
				Quaternion quat = Quaternion.FromAxisAngle(value.Axis, value.Angle);
				if (_rotation == quat)
					return;

				_rotation = quat;
				UpdateView();
			}
		}

		public float FovY
		{
			get => _fovY;
			set mut
			{
				if (_fovY == value)
					return;

				_fovY = value;
				UpdateProjection();
			}
		}
		
		public float NearPlane
		{
			get => _nearPlane;
			set mut
			{
				if (_nearPlane == value)
					return;

				_nearPlane = value;
				UpdateProjection();
			}
		}

		public float AspectRatio
		{
			get => _aspectRatio;
			set mut
			{
				if (_aspectRatio == value)
					return;

				_aspectRatio = value;
				UpdateProjection();
			}
		}

		public this(Vector3 position, Quaternion rotation, float fovY, float nearPlane, float aspectRatio)
		{
			_position = position;
			_rotation = rotation;
			_fovY = fovY;
			_nearPlane = nearPlane;
			_aspectRatio = aspectRatio;

			UpdateView();
			UpdateProjection();
		}

		public void Update(GameTime gameTime) mut
		{
			Debug.Profiler.ProfileFunction!();
			
			BindMouse = false;

			if (Input.IsKeyPressed(.Alt))
			{
				AltController(gameTime);
				_isAltMode = true;
			}
			else
			{
				FirstPersonController(gameTime);
				_isAltMode = false;
			}

			if (MouseCooldown != 0)
				MouseCooldown--;
		}

		void FirstPersonController(GameTime gameTime) mut
		{
			if (!Input.IsMouseButtonPressed(.RightButton))
				return;
			
			BindMouse = true; 

			bool transformChanged = false;

			Vector3 movement = .();

			if(Input.IsKeyPressed(Key.W))
				movement.Z += 1;
			if(Input.IsKeyPressed(Key.S))
				movement.Z -= 1;

			if(Input.IsKeyPressed(Key.A))
				movement.X -= 1;
			if(Input.IsKeyPressed(Key.D))
				movement.X += 1;

			if(Input.IsKeyPressed(Key.Space))
				movement.Y += 1;
			if(Input.IsKeyPressed(Key.Control))
				movement.Y -= 1;

			if(movement != .Zero)
			{
				movement.Normalize();
				
				if(Input.IsKeyPressed(Key.Shift))
					movement *= _cameraFastFactor;

				movement *= (float)(gameTime.DeltaTime) * _cameraTranslationSpeed;

				Vector4 delta = Vector4(movement, 1.0f) * _view;

				_position += delta.XYZ;

				transformChanged = true;
			}

			// Camera rotation
			var mouseDelta = Input.GetMouseMovement();

			float rotY = mouseDelta.X * _cameraRotationSpeedX;
			float rotX = mouseDelta.Y * _cameraRotationSpeedY;
			
			if (MouseCooldown == 0)
			{
				Vector3 rotationEuler = RotationEuler + Vector3(rotX, rotY, 0);
				_rotation = Quaternion.FromEulerAngles(rotationEuler.Y, rotationEuler.X, rotationEuler.Z);

				transformChanged = true;
			}

			if (transformChanged)
				UpdateView();
		}

		private float GetZoomSpeed()
		{
			float dist = _focalDistance * 0.2f;
			dist = Math.Max(dist, 0.0f);

			float speed = Math.Pow(dist, 1.5f);
			speed = Math.Min(speed, 100.0f);

			return speed;
		}

		void AltController(GameTime gameTime) mut
		{
			bool transformChanged = false;

			BindMouse = Input.IsMouseButtonPressed(.LeftButton) || Input.IsMouseButtonPressed(.RightButton); 

			var mouseDelta = Input.GetMouseMovement();
			
			if (MouseCooldown == 0 && Input.IsMouseButtonPressed(.LeftButton) && mouseDelta != .())
			{
				Vector2 movement = .(
					-mouseDelta.X,
					mouseDelta.Y);

				movement *= (float)(gameTime.DeltaTime) * _cameraTranslationSpeed * GetZoomSpeed();

				Vector4 delta = Vector4(movement, 0.0f, 1.0f) * _view;

				_focalPosition += delta.XYZ;

				transformChanged = true;
			}

			if (MouseCooldown == 0 && Input.IsMouseButtonPressed(.RightButton) && mouseDelta != .())
			{
				float rotY = mouseDelta.X * _cameraRotationSpeedX;
				float rotX = mouseDelta.Y * _cameraRotationSpeedY;

				Vector3 rotationEuler = RotationEuler + Vector3(rotX, rotY, 0);
				_rotation = Quaternion.FromEulerAngles(rotationEuler.Y, rotationEuler.X, rotationEuler.Z);

				transformChanged = true;
			}
			
			if (transformChanged)
				UpdateView();
		}

		private void UpdateView() mut
		{
			Matrix viewRotation = Matrix.RotationQuaternion(Quaternion.Inverse(_rotation));

			Vector4 offset = Vector4(0, 0, -_focalDistance, 1.0f) * viewRotation;
			if (_isAltMode)
				_position = _focalPosition + offset.XYZ;
			else
				_focalPosition = _position - offset.XYZ;

			_view = viewRotation * Matrix.Translation(-_position);

			//_view = (Matrix.Translation(_position) * Matrix.RotationQuaternion(_rotation)).Invert();
		}

		private void UpdateProjection() mut
		{
			//_projection = Matrix.InfinitePerspectiveProjection(_fovY, _aspectRatio, _nearPlane);
			_projection = Matrix.PerspectiveProjection(_fovY, _aspectRatio, _nearPlane, 10000);
		}

		public void OnViewportResize(uint32 sizeX, uint32 sizeY) mut
		{
			_aspectRatio = (float)sizeX / sizeY;
			UpdateProjection();
		}

		public bool OnMouseScrolled(MouseScrolledEvent event) mut
		{
			if (_isAltMode)
			{
				_focalDistance = Math.Max(_focalDistance - GetZoomSpeed() * event.YOffset, 0.01f);
				UpdateView();

				return true;
			}

			return false;
		}

		public void Dispose()
		{
			_renderTarget?.ReleaseRef();
		}
	}
}

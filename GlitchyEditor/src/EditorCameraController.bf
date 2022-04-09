using GlitchyEngine;
using GlitchyEngine.Math;
using GlitchyEngine.World;

namespace GlitchyEditor
{
	class EditorCameraController : ScriptableEntity
	{
		private float _cameraTranslationSpeed = 2.0f;
		private float _cameraRotationSpeedX = 0.001f;
		private float _cameraRotationSpeedY = 0.001f;

		public bool IsEnabled = false;

		protected override void OnUpdate(GameTime gt)
		{
			if (!IsEnabled)
				return;

			Debug.Profiler.ProfileFunction!();

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
			
			var transformComponent = transform;

			if(movement != .Zero)
			{
				movement.Normalize();

				movement *= (float)(gt.FrameTime.TotalSeconds) * _cameraTranslationSpeed;

				Matrix view = transformComponent.WorldTransform.Invert();

				Vector4 delta = Vector4(movement, 1.0f) * view;

				transformComponent.Position = transformComponent.Position + delta.XYZ;
			}

			// Camera rotation
			var mouseDelta = Input.GetMouseMovement();

			float rotY = mouseDelta.X * _cameraRotationSpeedX;
			float rotX = mouseDelta.Y * _cameraRotationSpeedY;

			transformComponent.RotationEuler = transformComponent.RotationEuler + .(rotX, rotY, 0);
		}
	}
}
using GlitchyEngine.Math;

namespace GlitchyEngine.World
{
	public struct TransformComponent
	{
		Vector3 _position = .Zero;
		Quaternion _rotation = .Identity;
		Vector3 _scale = .One;

		Matrix _localTransform = .Identity;
		public bool IsDirty = false;

		public Matrix WorldTransform = .Identity;

		/// The frame when the transform was recalculated
		public uint Frame;

		public Matrix LocalTransform
		{
			get => _localTransform;
			set mut
			{
				if(_localTransform == value)
					return;

				_localTransform = value;

				Matrix.Decompose(_localTransform, out _position, out _rotation, out _scale);
				IsDirty = true;
			}
		}

		public Vector3 Position
		{
			get => _position;
			set mut
			{
				if(_position == value)
					return;

				_position = value;
				IsDirty = true;
			}
		}

		/// Gets or sets the rotation.
		public Quaternion Rotation
		{
			get => _rotation;
			set mut
			{
				if(_rotation == value)
					return;

				_rotation = value;
				IsDirty = true;
			}
		}
		
		/**
		 * Gets or sets the rotation using euler angles.
		 * @Note The rotations will be applied in the following order: YZX (the order in the vector is still XYZ!)
		 */
		public Vector3 RotationEuler
		{
			get => Quaternion.ToEulerAngles(_rotation);
			set mut
			{
				Quaternion quat = Quaternion.FromEulerAngles(value.Y, value.X, value.Z);

				if(_rotation == quat)
					return;

				_rotation = quat;
				IsDirty = true;
			}
		}
		
		/**
		 * Gets or sets the rotation using axis angle, where Axis is the axis around which will be rotated and angle is the angle
		 * that was rotated around the axis in radians.
		 */
		public (Vector3 Axis, float Angle) RotationAxisAngle
		{
			get => _rotation.ToAxisAngle();
			set mut
			{
				Quaternion quat = Quaternion.FromAxisAngle(value.Axis, value.Angle);

				if(_rotation == quat)
					return;

				_rotation = quat;
				IsDirty = true;
			}
		}

		public Vector3 Scale
		{
			get => _scale;
			set mut
			{
				if(_scale == value)
					return;

				_scale = value;
				IsDirty = true;
			}
		}
	}
}

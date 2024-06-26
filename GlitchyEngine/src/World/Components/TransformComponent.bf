using GlitchyEngine.Math;

namespace GlitchyEngine.World
{
	public struct TransformComponent
	{
		EcsEntity _parent = .InvalidEntity;

		float3 _position = .(0, 0, 0);
		Quaternion _rotation = .(0, 0, 0, 1);
		float3 _scale = .(1, 1, 1);

		float3 _editorRotationEuler = .Zero;

		Matrix _localTransform = .Identity;
		public bool IsDirty = false;

		public Matrix WorldTransform = .Identity;

		/// The frame when the transform was recalculated
		public uint Frame;

		// TODO: probably use UUID
		public EcsEntity Parent
		{
			get => _parent;
			set mut
			{
				if (_parent == value)
					return;

				_parent = value;
				IsDirty = true;
			}
		}

		public Matrix LocalTransform
		{
			get => _localTransform;
			set mut
			{
				if(_localTransform == value)
					return;

				_localTransform = value;

				Matrix.Decompose(_localTransform, out _position, let rotation, out _scale);

				Rotation = rotation;

				IsDirty = true;
			}
		}

		public float3 Position
		{
			get => _position;
			set mut
			{
				if(all(_position == value))
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

				_editorRotationEuler = Quaternion.ToEulerAngles(_rotation);
			}
		}

		/// Allows the user to edit the euler angles in the editor without rotations getting funky because of singularities or ambiguity of angles.
		internal float3 EditorRotationEuler
		{
			get => _editorRotationEuler;
			set mut
			{
				if (all(_editorRotationEuler == value))
					return;

				_editorRotationEuler = value;

				_rotation = Quaternion.FromEulerAngles(_editorRotationEuler.Y, _editorRotationEuler.X, _editorRotationEuler.Z);
				IsDirty = true;
			}
		}
		
		/**
		 * Gets or sets the rotation using euler angles.
		 * @Note The rotations will be applied in the following order: YZX (the order in the vector is still XYZ!)
		 */
		public float3 RotationEuler
		{
			get => Quaternion.ToEulerAngles(normalize(_rotation));
			set mut => Rotation = Quaternion.FromEulerAngles(value.Y, value.X, value.Z);
		}
		
		/**
		 * Gets or sets the rotation using axis angle, where Axis is the axis around which will be rotated and angle is the angle
		 * that was rotated around the axis in radians.
		 */
		public (float3 Axis, float Angle) RotationAxisAngle
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

		public float3 Scale
		{
			get => _scale;
			set mut
			{
				if(all(_scale == value))
					return;

				_scale = value;
				IsDirty = true;
			}
		}
	}
}

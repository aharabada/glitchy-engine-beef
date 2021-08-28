using GlitchyEngine.Math;

namespace GlitchyEngine.World
{
	public struct TransformComponent
	{
		Vector3 _position = .Zero;
		Vector3 _rotation = .Zero;
		Vector3 _scale = .One;

		Matrix _localTransform;
		public bool IsDirty;

		public Matrix WorldTransform;

		/// The frame when the transform was recalculated
		public uint Frame;

		public Matrix LocalTransform
		{
			get => _localTransform;
			set mut => _localTransform = value;
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

		public Vector3 Rotation
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

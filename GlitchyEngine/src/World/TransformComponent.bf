using GlitchyEngine.Math;

namespace GlitchyEngine.World
{
	public struct TransformComponent
	{
		Vector3 _position = .Zero;
		Vector3 _rotation = .Zero;
		Vector3 _scale = .One;

		Matrix _transform;
		bool _dirty;

		public Matrix Transform
		{
			get mut
			{
				return _transform;
			}
			set mut => _transform = value;
		}
		public Vector3 Position
		{
			get => _position;
			set mut
			{
				if(_position == value)
					return;

				_position = value;
				_dirty = true;
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
				_dirty = true;
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
				_dirty = true;
			}
		}

		public void Update() mut
		{
			if(!_dirty)
				return;
			_transform = .Translation(_position) * .RotationX(_rotation.X) *
				.RotationY(_rotation.Y) * .RotationZ(_rotation.Z) * .Scaling(_scale);
			_dirty = false;
		}
	}
}

using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public class OrthographicCamera : Camera
	{
		protected float _bottom, _left, _right, _top;

		public float Bottom
		{
			get => _bottom;
			set
			{
				if(_bottom == value)
					return;

				_bottom = value;
				_projectionOutdated = true;
			}
		}
		
		public float Left
		{
			get => _left;
			set
			{
				if(_left == value)
					return;

				_left = value;
				_projectionOutdated = true;
			}
		}
		
		public float Right
		{
			get => _right;
			set
			{
				if(_right == value)
					return;

				_right = value;
				_projectionOutdated = true;
			}
		}
		
		public float Top
		{
			get => _top;
			set
			{
				if(_top == value)
					return;

				_top = value;
				_projectionOutdated = true;
			}
		}

		public float Width
		{
			get => _right - _left;
			set
			{
				Left = -value / 2.0f;
				Right = value / 2.0f;
			}
		}
		
		public float Height
		{
			get => _top - _bottom;
			set
			{
				Bottom = -value / 2.0f;
				Top = value / 2.0f;
			}
		}

		protected override void UpdateProjection()
		{
			Debug.Profiler.ProfileFunction!();

			_projection = Matrix.OrthographicProjectionOffCenter(_left, _right, _top, _bottom, _nearPlane, _farPlane);
		}

		protected override void UpdateTransform()
		{
			Debug.Profiler.ProfileFunction!();

			_transform = Matrix.Translation(_position) * Matrix.RotationZ(_rotation.Z) * Matrix.RotationY(_rotation.Y) * Matrix.RotationX(_rotation.X);
			_view = _transform.Invert();
		}
	}
}

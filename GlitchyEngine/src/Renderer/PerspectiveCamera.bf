using System;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	/**
	 * If FarPlane is float.PositiveInfinity the projection matrix will be an infinite projection (that means no far plane)
	 */
	public class PerspectiveCamera : Camera
	{
		public enum ProjectionType
		{
			/**
			 * The projection has a near and a far plane. The near plane has a depth of 0, the far plane a depth of 1.
			 */
			Limited,
			/**
			 * The projection has a near and a far plane. The near plane has a depth of 1, the far plane a depth of 0.
			 */
			LimitedReversed,
			/**
			 * The projection only has a near. The near plane has a depth of 0; infinite distance has a value of 1.
			 */
			Infinite,
			/**
			 * The projection only has a near. The near plane has a depth of 1; infinite distance has a value of 0.
			 */
			InfiniteReversed
		}

		protected ProjectionType _projectionType;

		protected float _fovY;
		
		protected float _aspect;

		/**
		 * Gets or Sets the projection type.
		 */
		public ProjectionType ProjectionType
		{
			get => _projectionType;
			set
			{
				if(_projectionType == value)
					return;

				_projectionType = value;
				_projectionOutdated = true;
			}
		}

		public float FovY
		{
			get => _fovY;
			set
			{
				if(_fovY == value)
					return;

				_fovY = value;
				_projectionOutdated = true;
			}
		}

		public float AspectRatio
		{
			get => _aspect;
			set
			{
				if(_aspect == value)
					return;

				_aspect = value;
				_projectionOutdated = true;
			}
		}

		protected override void UpdateProjection()
		{
			Log.EngineLogger.Assert(_nearPlane < _farPlane, "The near plane must be smaller than the far plane.");

			switch(_projectionType)
			{
			case .Limited:
				_projection = Matrix.PerspectiveProjection(_fovY, _aspect, _nearPlane, _farPlane);
			case .LimitedReversed:
				_projection = Matrix.ReversedPerspectiveProjection(_fovY, _aspect, _nearPlane, _farPlane);
			case .Infinite:
				_projection = Matrix.InfinitePerspectiveProjection(_fovY, _aspect, _nearPlane, 10e-6f); // todo: epsilon
			case .InfiniteReversed:
				_projection = Matrix.ReversedInfinitePerspectiveProjection(_fovY, _aspect, _nearPlane, 10e-6f); // todo: epsilon
			default:
				Log.EngineLogger.Assert(false, "Unknown projection type.");
			}
		}

		protected override void UpdateTransform()
		{
			_transform = Matrix.Translation(_position) * Matrix.RotationZ(_rotation.Z) * Matrix.RotationY(_rotation.Y) * Matrix.RotationX(_rotation.X);
			_view = _transform.Invert();
		}
	}
}

using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public struct CameraComponent
	{
		public enum Projection
		{
			/**
			 * A perspective projection with near and far plane.
			 */
			Perspective,
			/**
			 * A perspective projection with near and far plane,
			 * except that the closer a pixel is to the far plane the smaller its depth-value gets.
			 */
			PerspectiveReversed,
			/**
			 * A perspective projection with a near plane and a far plane at infinite distance.
			 */
			PerspectiveInfinite,
			/**
			 * A perspective projection with a near plane and a far plane at infinite distance,
			 * except that the closer a pixel is to the far plane the smaller its depth-value gets.
			 */
			PerspectiveReversedInfinite,
			/**
			 * An orthographic projection.
			 */
			Orthographic
		}

		float _nearPlane;
		float _farPlane;
		Projection _projectionType;
		float _fovY;
		float _aspect;

		public float NearPlane
		{
			get => _nearPlane;
			set mut => _nearPlane = value;
		}
		
		public float FarPlane
		{
			get => _farPlane;
			set mut => _farPlane = value;
		}

		public Projection ProjectionType
		{
			get => _projectionType;
			set mut => _projectionType = value;
		}
		
		public float FovY
		{
			get => _fovY;
			set mut => _fovY = value;
		}
		
		public float FovX
		{
			get => _fovY * _aspect;
			set mut => _fovY = value / _aspect;
		}
		
		public float Aspect
		{
			get => _aspect;
			set mut => _aspect = value;
		}

		public Matrix Projection => CalculateProjection();

		public Matrix CalculateProjection()
		{
			Log.EngineLogger.Assert(_nearPlane < _farPlane, "The near plane must be smaller than the far plane.");

			switch(_projectionType)
			{
			case .Perspective:
				return Matrix.PerspectiveProjection(_fovY, _aspect, _nearPlane, _farPlane);
			case .PerspectiveReversed:
				return Matrix.ReversedPerspectiveProjection(_fovY, _aspect, _nearPlane, _farPlane);
			case .PerspectiveInfinite:
				return Matrix.InfinitePerspectiveProjection(_fovY, _aspect, _nearPlane);
			case .PerspectiveReversedInfinite:
				return Matrix.ReversedInfinitePerspectiveProjection(_fovY, _aspect, _nearPlane);
			default:
				Log.EngineLogger.Assert(false, "Unknown projection type.");
			}

			return .Identity;
		}
	}
}

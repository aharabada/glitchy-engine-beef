using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;

namespace GlitchyEngine.World
{
	struct SimpleTransformComponent
	{
		public Matrix Transform = Matrix.Identity;

		public this()
		{

		}	

		public this(Matrix transform)
		{
			Transform = transform;
		}
	}
	
	struct SpriterRendererComponent
	{
		public ColorRGBA Color = .White;

		public this()
		{

		}

		public this(ColorRGBA color)
		{
			Color = color;
		}
	}

	struct SceneCamera : Camera
	{
		public enum ProjectionType
		{
			case Perspective(float FovY, float NearPlane, float FarPlane);
			case InfinitePerspective(float FovY, float NearPlane);
			case Orthographic(float Height, float NearPlane, float FarPlane);
		}

		private float _aspectRatio = 16.0f / 9.0f;

		private ProjectionType _projectionType = .InfinitePerspective(MathHelper.ToRadians(75f), 0.1f);

		public ProjectionType ProjectionType
		{
			get => _projectionType;
			set mut
			{
				_projectionType = value;
				CalculateProjection();
			}
		}

		private const Matrix mat = Matrix.InfinitePerspectiveProjection(MathHelper.ToRadians(75f), 1.0f, 0.1f);

		public this()
		{
			CalculateProjection();
		}

		public void SetOrthographic(float height, float nearPlane, float farPlane) mut
		{
			_projectionType = .Orthographic(height, nearPlane, farPlane);

			CalculateProjection();
		}
		
		public void SetPerspective(float fovY, float nearPlane, float farPlane) mut
		{
			_projectionType = .Perspective(fovY, nearPlane, farPlane);

			CalculateProjection();
		}

		public void SetInfinitePerspective(float fovY, float nearPlane) mut
		{
			_projectionType = .InfinitePerspective(fovY, nearPlane);

			CalculateProjection();
		}

		public void SetViewportSize(uint32 width, uint32 height) mut
		{
			_aspectRatio = (float)width / (float)height;

			CalculateProjection();
		}

		private void CalculateProjection() mut
		{
			if (_projectionType case .Orthographic(let nearPlane, let farPlane, let projectionHeight))
			{
				float halfHeight = projectionHeight / 2.0f;
				float halfWidth = halfHeight / _aspectRatio;

				_projection = Matrix.OrthographicProjectionOffCenter(-halfWidth, halfWidth, halfHeight, -halfHeight, nearPlane, farPlane);
			}
			else if (_projectionType case .Perspective(let nearPlane, let farPlane, let fovY))
			{
				_projection = Matrix.PerspectiveProjection(fovY, _aspectRatio, nearPlane, farPlane);
			}
			else if (_projectionType case .InfinitePerspective(let nearPlane, let fovY))
			{
				_projection = Matrix.InfinitePerspectiveProjection(fovY, _aspectRatio, nearPlane);
			}
		}
	}

	struct CameraComponent
	{
		public SceneCamera Camera;
		public bool Primary = true; // Todo: probably move into scene
		public bool FixedAspectRatio = false;

		public this()
		{
			Camera = .();
		}	
	}
}
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;

namespace GlitchyEngine.World
{
	/// If an entity has the EditorComponent it won't be displayed in the scene hierarchy.
	struct EditorComponent
	{
		bool b = false;
		public this()
		{

		}
	}

	struct SimpleTransformComponent
	{
		public EcsEntity Parent = .InvalidEntity;
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
			case Orthographic = 0;//(float Height, float NearPlane, float FarPlane);
			case Perspective = 1;//(float FovY, float NearPlane, float FarPlane);
			case InfinitePerspective = 2;//(float FovY, float NearPlane);
		}

		private float _perspectiveFovY = MathHelper.ToRadians(75f);
		private float _perspectiveNearPlane = 0.1f;
		private float _perspectiveFarPlane = 10000.0f;

		private float _orthographicHeight = 10.0f;
		private float _orthographicNearPlane = 0.0f;
		private float _orthographicFarPlane = 10.0f;

		private float _aspectRatio = 16.0f / 9.0f;

		private bool _fixedAspectRatio = false;

		private ProjectionType _projectionType = .InfinitePerspective;//(MathHelper.ToRadians(75f), 0.1f);

		public ProjectionType ProjectionType
		{
			get => _projectionType;
			set mut
			{
				_projectionType = value;
				CalculateProjection();
			}
		}

		public float PerspectiveFovY
		{
			get => _perspectiveFovY;
			set mut
			{
				if (_perspectiveFovY == value)
					return;

				_perspectiveFovY = value;
				CalculateProjection();
			}
		}

		public float PerspectiveNearPlane
		{
			get => _perspectiveNearPlane;
			set mut
			{
				if (_perspectiveNearPlane == value)
					return;

				_perspectiveNearPlane = value;
				CalculateProjection();
			}
		}

		public float PerspectiveFarPlane
		{
			get => _perspectiveFarPlane;
			set mut
			{
				if (_perspectiveFarPlane == value)
					return;

				_perspectiveFarPlane = value;
				CalculateProjection();
			}
		}

		public float OrthographicHeight
		{
			get => _orthographicHeight;
			set mut
			{
				if (_orthographicHeight == value)
					return;

				_orthographicHeight = value;
				CalculateProjection();
			}
		}

		public float OrthographicNearPlane
		{
			get => _orthographicNearPlane;
			set mut
			{
				if (_orthographicNearPlane == value)
					return;

				_orthographicNearPlane = value;
				CalculateProjection();
			}
		}

		public float OrthographicFarPlane
		{
			get => _orthographicFarPlane;
			set mut
			{
				if (_orthographicFarPlane == value)
					return;

				_orthographicFarPlane = value;
				CalculateProjection();
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
				CalculateProjection();
			}
		}

		public bool FixedAspectRatio
		{
			get => _fixedAspectRatio;
			set mut
			{
				if (_fixedAspectRatio == value)
					return;

				_fixedAspectRatio = value;
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
			_projectionType = .Orthographic;//(height, nearPlane, farPlane);

			_orthographicHeight = height;
			_orthographicNearPlane = nearPlane;
			_orthographicFarPlane = farPlane;

			CalculateProjection();
		}
		
		public void SetPerspective(float fovY, float nearPlane, float farPlane) mut
		{
			_projectionType = .Perspective;//(fovY, nearPlane, farPlane);
			_perspectiveFovY = fovY;
			_perspectiveNearPlane = nearPlane;
			_perspectiveFarPlane = farPlane;

			CalculateProjection();
		}

		public void SetInfinitePerspective(float fovY, float nearPlane) mut
		{
			_projectionType = .InfinitePerspective;//(fovY, nearPlane);
			_perspectiveFovY = fovY;
			_perspectiveNearPlane = nearPlane;
			//_perspectiveFarPlane = farPlane;

			CalculateProjection();
		}

		public void SetViewportSize(uint32 width, uint32 height) mut
		{
			_aspectRatio = (float)width / (float)height;

			CalculateProjection();
		}

		private void CalculateProjection() mut
		{
			if (_projectionType case .Orthographic)//(let nearPlane, let farPlane, let projectionHeight))
			{
				float halfHeight = _orthographicHeight / 2.0f;
				float halfWidth = halfHeight * _aspectRatio;

				_projection = Matrix.OrthographicProjectionOffCenter(-halfWidth, halfWidth, halfHeight, -halfHeight,
					_orthographicNearPlane, _orthographicFarPlane);
			}
			else if (_projectionType case .Perspective)//(let nearPlane, let farPlane, let fovY))
			{
				_projection = Matrix.PerspectiveProjection(_perspectiveFovY, _aspectRatio, _perspectiveNearPlane, _perspectiveFarPlane);
			}
			else if (_projectionType case .InfinitePerspective)//(let nearPlane, let fovY))
			{
				_projection = Matrix.InfinitePerspectiveProjection(_perspectiveFovY, _aspectRatio, _perspectiveNearPlane);
			}
		}
	}

	struct CameraComponent
	{
		public SceneCamera Camera;
		public bool Primary = true;  // Todo: probably move into scene
		public bool FixedAspectRatio = false;

		public this()
		{
			Camera = .();
		}	
	}

	struct NativeScriptComponent : IDisposableComponent
	{
		public ScriptableEntity Instance = null;
		
		public function void (mut NativeScriptComponent this) Func;

		public function ScriptableEntity () InstantiateFunction;
		public function void (NativeScriptComponent* self) DestroyInstanceFunction;

		public void Bind<T>() mut where T : ScriptableEntity
		{
			InstantiateFunction = () =>
				{
					return new T();
				};

			DestroyInstanceFunction = (self) =>
				{
					delete self.Instance;
				};
		}

		public void Dispose() mut
		{
			DestroyInstanceFunction(&this);
		}
	}
}
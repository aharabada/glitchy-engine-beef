using System;
using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using GlitchyEngine.Core;
using Box2D;
using GlitchyEngine.Content;
using GlitchyEngine.Scripting;
using Mono;

namespace GlitchyEngine.World
{
	/// Components that implement this interface provide custom copy logic.
	interface ICopyComponent<T>
	{
		/// Copies the data from source to target.
		concrete static void Copy(T* source, T* target);
	}

	[AttributeUsage(.Struct, .ReflectAttribute, ReflectUser=.Methods | .NonStaticFields)]
	struct ComponentAttribute : Attribute
	{
		public String Name;

		public this(String name)
		{
			Name = name;
		}
	}

	struct IDComponent
	{
		public readonly UUID ID;

		public this()
		{
			ID = .Zero;
		}

		public this(UUID id)
		{
			ID = id;
		}
	}

	[Component("Sprite Renderer")]
	struct SpriteRendererComponent
	{
		public AssetHandle<Texture2D> Sprite = .Invalid;

		public ColorRGBA Color = .White;
		public float4 UvTransform = .(0, 0, 1, 1);

		public this()
		{
		}

		public this(ColorRGBA color)
		{
			Color = color;
		}
	}

	[Component("Circle Renderer")]
	struct CircleRendererComponent
	{
		public AssetHandle<Texture2D> Sprite = .Invalid;

		public ColorRGBA Color = .White;
		public float4 UvTransform = .(0, 0, 1, 1);

		public float InnerRadius = 0.0f;

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
			if (_projectionType case .Orthographic)
			{
				float halfHeight = _orthographicHeight / 2.0f;
				float halfWidth = halfHeight * _aspectRatio;

				_projection = Matrix.OrthographicProjectionOffCenter(-halfWidth, halfWidth, halfHeight, -halfHeight,
					// Swap far and near plane, because we use reversed depth!
					_orthographicFarPlane, _orthographicNearPlane);
			}
			else if (_projectionType case .Perspective)
			{
				_projection = Matrix.ReversedPerspectiveProjection(_perspectiveFovY, _aspectRatio, _perspectiveNearPlane, _perspectiveFarPlane);
			}
			else if (_projectionType case .InfinitePerspective)
			{
				_projection = Matrix.ReversedInfinitePerspectiveProjection(_perspectiveFovY, _aspectRatio, _perspectiveNearPlane);
			}
		}
	}

	struct CameraComponent : IDisposableComponent
	{
		public SceneCamera Camera = .();
		public bool Primary = true;  // Todo: probably move into scene
		private RenderTargetGroup _renderTarget = null;

		public RenderTargetGroup RenderTarget
		{
			get => _renderTarget;
			set mut
			{
				SetReference!(_renderTarget, value);
			}
		}

		public void Dispose()
		{
			_renderTarget?.ReleaseRef();
		}
	}

	struct SceneLight
	{
		public enum LightType
		{
			Directional = 0,
			Spot = 1,
			Point = 2
		}

		private LightType _type = .Directional;

		private float _illuminance = 10.0f;

		private ColorRGB _color = .(1, 1, 1);

		public LightType LightType
		{
			get => _type;
			set mut => _type = value;
		}

		public ColorRGB Color
		{
			get => _color;
			set mut => _color = value;
		}
		
		public float Illuminance
		{
			get => _illuminance;
			set mut => _illuminance = value;
		}
	}

	struct LightComponent
	{
		public SceneLight SceneLight;
	}

	struct Rigidbody2DComponent : IDisposableComponent, ICopyComponent<Rigidbody2DComponent>
	{
		public enum BodyType
		{
			case Static = 0; case Dynamic = 1; case Kinematic = 2;

			public b2BodyType GetBox2DBodyType()
			{
				switch (this)
				{
				case .Static:
					return .b2_staticBody;
				case .Dynamic:
					return .b2_dynamicBody;
				case .Kinematic:
					return .b2_kinematicBody;
				default:
					Log.EngineLogger.AssertDebug(false, "Unknown body type");
					return .b2_staticBody;
				}
			}
		}

		private BodyType _bodyType = .Static;

		private bool _fixedRotation = false;
		private float _gravityScale = 1.0f;

		private int _runtimeBody = 0;

		//private float _linearDamping = 0.0f;
		//private float _angularDamping = 0.01f;

		protected internal b2Body* RuntimeBody
		{
			[Inline]
			get => (b2Body*)(void*)_runtimeBody;
			[Inline]
			set mut => _runtimeBody = (int)(void*)value;
		}
		
		public static void Copy(Self* source, Self* target)
		{
			target._bodyType = source._bodyType;
			target._fixedRotation = source._fixedRotation;
			target._gravityScale = source._gravityScale;
		}

		public BodyType BodyType
		{
			get => _bodyType;
			set mut
			{
				_bodyType = value;

				if (RuntimeBody != null)
				{
					Box2D.Body.SetBodyType(RuntimeBody, _bodyType.GetBox2DBodyType());
				}
			}
		}
		
		public bool FixedRotation
		{
			get => _fixedRotation;
			set mut
			{
				_fixedRotation = value;

				if (RuntimeBody != null)
				{
					Box2D.Body.SetFixedRotation(RuntimeBody, _fixedRotation);
				}
			}
		}

		public float GravityScale
		{
			get => _gravityScale;
			set mut
			{
				_gravityScale = value;

				if (RuntimeBody != null)
				{
					Box2D.Body.SetGravityScale(RuntimeBody, _gravityScale);
				}
			}
		}

		/*public float LinearDamping
		{
			get => _linearDamping;
			set mut
			{
				_linearDamping = value;

				if (RuntimeBody != null)
					Box2D.Body.SetLinearDamping(RuntimeBody, _linearDamping);
			}
		}

		public float AngularDamping
		{
			get => _angularDamping;
			set mut
			{
				_angularDamping = value;

				if (RuntimeBody != null)
					Box2D.Body.SetAngularDamping(RuntimeBody, _angularDamping);
			}
		}*/
		
		public float2 GetPosition()
		{
			if (RuntimeBody != null)
			{
				Box2D.b2Vec2 vec = Box2D.Body.GetPosition(RuntimeBody);

				return *(float2*)&vec;
			}

			return .Zero;
		}

		public void SetPosition(float2 position)
		{
			var position;

			if (RuntimeBody != null)
			{
				float angle = Box2D.Body.GetAngle(RuntimeBody);

				Box2D.Body.SetTransform(RuntimeBody, position, angle);
			}
		}
		
		public float GetAngle()
		{
			if (RuntimeBody != null)
			{
				return Box2D.Body.GetAngle(RuntimeBody);
			}

			return float.NaN;
		}

		public void SetAngle(float angle)
		{
			if (RuntimeBody != null)
			{
				var pos = Box2D.Body.GetPosition(RuntimeBody);

				Box2D.Body.SetTransform(RuntimeBody, pos, angle);
			}
		}
		
		public float2 GetLinearVelocity()
		{
			if (RuntimeBody != null)
			{
				Box2D.b2Vec2 vec = Box2D.Body.GetLinearVelocity(RuntimeBody);

				return *(float2*)&vec;
			}

			return .Zero;
		}

		public void SetLinearVelocity(float2 velocity)
		{
			if (RuntimeBody != null)
				Box2D.Body.SetLinearVelocity(RuntimeBody, velocity);
		}
		
		public float GetAngularVelocity()
		{
			if (RuntimeBody != null)
			{
				return Box2D.Body.GetAngularVelocity(RuntimeBody);
			}

			return 0;
		}

		public void SetAngularVelocity(float velocity)
		{
			if (RuntimeBody != null)
				Box2D.Body.SetAngularVelocity(RuntimeBody, velocity);
		}

		public void Dispose()
		{
			if (RuntimeBody != null && ScriptEngine.Context?.[Friend]_physicsWorld2D != null)
				Box2D.World.DestroyBody(ScriptEngine.Context.[Friend]_physicsWorld2D, RuntimeBody);
		}
	}

	/*struct InternalBug
	{
		private int i;

		internal int MyInt
		{
			get => i;
			set mut => i = value;
		}

		public void Bla()
		{
			MyInt = 5;
		}
	}*/

	struct BoxCollider2DComponent : ICopyComponent<BoxCollider2DComponent>
	{
		public float2 Offset = .(0.0f, 0.0f);
		public float2 Size = .(0.5f, 0.5f);

		// TODO: move into 2D physics material
		public float Density = 1.0f;
		public float Friction = 0.5f;
		public float Restitution = 0.0f;
		public float RestitutionThreshold = 0.5f;

		private int _runtimeFixture = 0;

		internal b2Fixture* RuntimeFixture
		{
			[Inline]
			get => (b2Fixture*)(void*)_runtimeFixture;
			[Inline]
			set mut => _runtimeFixture = (int)(void*)value;
		}
		
		[Inline]
		internal ref b2Vec2 b2Offset mut => ref *(Box2D.b2Vec2*)(void*)&Offset;
		
		public static void Copy(Self* source, Self* target)
		{
			target.Offset = source.Offset;
			target.Density = source.Density;
			target.Friction = source.Friction;
			target.Restitution = source.Restitution;
			target.RestitutionThreshold = source.RestitutionThreshold;
		}
	}

	struct CircleCollider2DComponent : ICopyComponent<CircleCollider2DComponent>
	{
		public float2 Offset = .(0.0f, 0.0f);

		public float Radius = 0.5f;

		// TODO: move into 2D physics material
		public float Density = 1.0f;
		public float Friction = 0.5f;
		public float Restitution = 0.0f;
		public float RestitutionThreshold = 0.5f;

		private int _runtimeFixture = 0;

		internal b2Fixture* RuntimeFixture
		{
			[Inline]
			get => (b2Fixture*)(void*)_runtimeFixture;
			[Inline]
			set mut => _runtimeFixture = (int)(void*)value;
		}
		
		[Inline]
		internal ref b2Vec2 b2Offset mut => ref *(Box2D.b2Vec2*)(void*)&Offset;

		public static void Copy(Self* source, Self* target)
		{
			target.Offset = source.Offset;
			target.Radius = source.Radius;
			target.Density = source.Density;
			target.Friction = source.Friction;
			target.Restitution = source.Restitution;
			target.RestitutionThreshold = source.RestitutionThreshold;
		}
	}

	// Todo: This component is rather large (> 1 Cache line)
	struct PolygonCollider2DComponent : ICopyComponent<PolygonCollider2DComponent>
	{
		public float2 Offset = .(0.0f, 0.0f);

		// TODO: move into 2D physics material
		public float Density = 1.0f;
		public float Friction = 0.5f;
		public float Restitution = 0.0f;
		public float RestitutionThreshold = 0.5f;

		// initialize with a well formed shape
		public float2[8] Vertices = .(.(-0.5f, -0.5f), .(0.5f, -0.5f), .(0.5f, 0.5f), .(-0.5f, 0.5f),);
		public int8 VertexCount = 4;

		private int _runtimeFixture = 0;

		internal b2Fixture* RuntimeFixture
		{
			[Inline]
			get => (b2Fixture*)(void*)_runtimeFixture;
			[Inline]
			set mut => _runtimeFixture = (int)(void*)value;
		}
		
		[Inline]
		internal ref b2Vec2 b2Offset mut => ref *(Box2D.b2Vec2*)(void*)&Offset;

		public static void Copy(Self* source, Self* target)
		{
			target.Offset = source.Offset;
			target.Density = source.Density;
			target.Friction = source.Friction;
			target.Restitution = source.Restitution;
			target.Vertices = source.Vertices;
			target.VertexCount = source.VertexCount;
		}
	}

	struct ScriptComponent : IDisposableComponent
	{
		private String _scriptClassName = null;

		private ScriptInstance _instance = null;

		public StringView ScriptClassName
		{
			get => _scriptClassName;
			set mut
			{
				if (_scriptClassName == null)
					_scriptClassName = new String(value);

				_scriptClassName.Set(value);
			}
		}

		public ScriptInstance Instance
		{
			[Inline]
			get => _instance;
			[Inline]
			set mut => SetReference!(_instance, value);
		}

		public bool IsInitialized => _instance?.IsInitialized ?? false;

		public bool IsCreated => _instance?.IsCreated ?? false;

		public void Dispose() mut
		{
			delete _scriptClassName;
			ReleaseRefAndNullify!(_instance);
		}
	}
}
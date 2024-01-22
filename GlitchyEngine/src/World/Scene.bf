using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;
using System.Collections;
using Box2D;
using GlitchyEngine.Core;
using GlitchyEngine.Content;
using GlitchyEngine.Scripting;
using GlitchyEngine.Math;
using GlitchyEngine.Scripting.Classes;
using GlitchyEngine.Serialization;

namespace GlitchyEngine.World
{
	using internal ScriptableEntity;
	using internal GlitchyEngine.World;

	class Scene : RefCounter
	{
		private String _name = new String("New Scene") ~ delete _;

		internal EcsWorld _ecsWorld = new .() ~ delete _;

		internal b2World* _physicsWorld2D;
		b2ContactListener _contactListener;
		b2Draw draw = .();

		private float _fixedDeltaTime = 1.0f / 60.0f;

		private Physics2DSettings _physics2dSettings = .(this);

		[Inline]
		public ref Physics2DSettings Physics2DSettings => ref _physics2dSettings;

		private Dictionary<Type, function void(Entity entity, Type componentType, void* component)> _onComponentAddedHandlers = new .() ~ delete _;

		private uint32 _viewportWidth, _viewportHeight;

		// Maps ids to the entities they represent.
		private Dictionary<UUID, EcsEntity> _idToEntity = new .() ~ delete _;

		private HashSet<EcsEntity> _updateBlockList = new .() ~ delete _;

		public Entity ActiveCamera => {
			Entity cameraEntity = .();

		  	for (var (entity, camera) in _ecsWorld.Enumerate<CameraComponent>())
			{
				if (camera.Primary && camera.RenderTarget != null)
				{
					cameraEntity = .(entity, this);
				}
			}

			cameraEntity
		};

		/// Gets or sets the name of the scene.
		public StringView Name
		{
			get => _name;
			set
			{
				_name.Set(value);
			}
		}

		public this()
		{
			_onComponentAddedHandlers.Add(typeof(CameraComponent), (e, t, c) => {
				CameraComponent* cameraComponent = (.)c;

				cameraComponent.Camera.SetViewportSize(e.Scene._viewportWidth, e.Scene._viewportHeight);
			});

			_onComponentAddedHandlers.Add(typeof(Rigidbody2DComponent), (e, t, c) => {
				Rigidbody2DComponent* rigidbodyComponent = (.)c;

				Scene scene = e.Scene;

				if (scene._physicsWorld2D != null)
				{
					scene.InitializeRigidbody2D(e, rigidbodyComponent);
				}
			});

			_onComponentAddedHandlers.Add(typeof(BoxCollider2DComponent), (e, t, c) => {
				BoxCollider2DComponent* collider = (.)c;

				Scene scene = e.Scene;

				if (scene._physicsWorld2D != null)
				{
					scene.InitBoxCollider2D(e, collider);
				}
			});

			_onComponentAddedHandlers.Add(typeof(CircleCollider2DComponent), (e, t, c) => {
				CircleCollider2DComponent* collider = (.)c;

				Scene scene = e.Scene;

				if (scene._physicsWorld2D != null)
				{
					scene.InitCircleCollider2D(e, collider);
				}
			});

			_onComponentAddedHandlers.Add(typeof(PolygonCollider2DComponent), (e, t, c) => {
				PolygonCollider2DComponent* collider = (.)c;

				Scene scene = e.Scene;

				if (scene._physicsWorld2D != null)
				{
					scene.InitPolygonCollider2D(e, collider);
				}
			});
		}

		public ~this()
		{
		}

		/// Copies all entities with their components to the given target-scene.
		/// @param target The scene that the entities are copied to.
		/// @param copyScripts If true script components will be copied. 
		///			This is for simulation mode, where the script-components won't be executing, thus we don't copy them.
		///			TODO: But in reality we still might want to have scripts, because the user might want to run some code, just not OnCreate/OnUpdate?
		///			TODO: Honestly, I'm not quite sure what simulation mode is actually good for. Maybe we better just remove it?
		public void CopyTo(Scene target, bool copyScripts)
		{
			// Copy entities
			for (let sourceHandle in _ecsWorld.Enumerate())
			{
				Entity sourceEntity = .(sourceHandle, this);

				target.CreateEntity(sourceEntity.Name, sourceEntity.UUID);
			}

			// TODO: perhaps use reflection and comptime
			// Copy components
			CopyComponents<MeshRendererComponent>(this, target);
			CopyComponents<MeshComponent>(this, target);
			CopyComponents<EditorComponent>(this, target);
			CopyComponents<SpriteRendererComponent>(this, target);
			CopyComponents<CircleRendererComponent>(this, target);
			CopyComponents<CameraComponent>(this, target);
			CopyComponents<LightComponent>(this, target);
		
			CopyComponents<Rigidbody2DComponent>(this, target);
			CopyComponents<BoxCollider2DComponent>(this, target);
			CopyComponents<CircleCollider2DComponent>(this, target);
			CopyComponents<PolygonCollider2DComponent>(this, target);

			if (copyScripts)
			{
				for (let (sourceHandle, sourceScript) in _ecsWorld.Enumerate<ScriptComponent>())
				{
					Entity sourceEntity = .(sourceHandle, target);

					Entity targetEntity = target.GetEntityByID(sourceEntity.UUID);
					ScriptComponent* targetScript = targetEntity.AddComponent<ScriptComponent>();

					targetScript.ScriptClassName = sourceScript.ScriptClassName;
				}
			}

			// Copy transforms... needs special handling for the Parent<->Child relations
			for (let (sourceHandle, sourceTransform) in _ecsWorld.Enumerate<TransformComponent>())
			{
				Entity sourceEntity = Entity(sourceHandle, this);
				Entity sourceParent = Entity(sourceTransform.Parent, this);
				
				Entity targetEntity = target.GetEntityByID(sourceEntity.UUID);
				*targetEntity.Transform = *sourceTransform;

				if (sourceParent.IsValid)
				{
					Entity targetParent = target.GetEntityByID(sourceParent.UUID);
					targetEntity.Parent = targetParent;
				}
			}
			
			//target.SetViewportSize(_viewportWidth, _viewportHeight);
		}

		private static void CopyComponents<TComponent>(Scene source, Scene target) where TComponent : struct, new
		{
			for (let (sourceHandle, sourceComponent) in source._ecsWorld.Enumerate<TComponent>())
			{
				Entity sourceEntity = .(sourceHandle, source);

				Entity targetEntity = target.GetEntityByID(sourceEntity.UUID);
				targetEntity.AddComponent<TComponent>(*sourceComponent);
			}
		}

		private static void CopyComponent<TComponent>(Entity source, Entity target) where TComponent : struct, new
		{
			if (source.TryGetComponent<TComponent>(let component))
			{
				target.AddComponent<TComponent>(*component);
			}
		}

		static b2BodyType GetBox2DBodyType(Rigidbody2DComponent.BodyType bodyType)
		{
			switch (bodyType)
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

		/**
		 * Starts the scene.
		 * @param startRuntime If true, the script runtime will be started.
		 * @param startSimulation If true, the physics engine will be started.
		 */
		public void Start(bool startRuntime, bool startSimulation)
		{
			if (startSimulation)
				StartSimulation();

			if (startRuntime)
			{
				StartRuntime();
				
				if (startSimulation)
				{
					SetupPhysicsCallbacks();
				}
			}
		}
		
		/**
		 * Stops the scene by shutting down the script runtime and physics simulation.
		 */
		public void Stop()
		{
			StopRuntime();
			StopSimulation();
		}

		private void StartRuntime()
		{
			ScriptEngine.StartRuntime(this);

			// Initialize ScriptComponents
			for (let (handle, scriptComponent) in _ecsWorld.Enumerate<ScriptComponent>())
			{
				Entity entity = .(handle, this);
				// TODO: this returns false, if no script with ScriptClassName exists, we have to handle this case correctly
				ScriptEngine.InitializeInstance(entity, scriptComponent);
			}
		}

		private void StopRuntime()
		{
			ScriptEngine.StopRuntime();
		}

		private void StartSimulation()
		{
			// TODO: Add Setting for the user to define whether Physics will be initialized or not?
			
			_physicsWorld2D = World.Create(_physics2dSettings.Gravity);

			draw.drawPolygonCallback = (vertices, vertexCount, color, userData) =>
				{
					for (int i = 1; i < vertexCount; i++)
					{
						let start = vertices[i - 1];
						let end = vertices[i];

						Renderer2D.DrawLine(float3(start.x, start.y, 0.0f), float3(end.x, end.y, 0.0f), *(ColorRGBA*)&color);
					}
					let start = vertices[vertexCount - 1];
					let end = vertices[0];

					Renderer2D.DrawLine(float3(start.x, start.y, 0.0f), float3(end.x, end.y, 0.0f), *(ColorRGBA*)&color);
				};
			draw.drawSolidPolygonCallback = (vertices, vertexCount, color, userData) =>
				{
					for (int i = 1; i < vertexCount; i++)
					{
						let start = vertices[i - 1];
						let end = vertices[i];

						Renderer2D.DrawLine(float3(start.x, start.y, 0.0f), float3(end.x, end.y, 0.0f), *(ColorRGBA*)&color);
					}
					let start = vertices[vertexCount - 1];
					let end = vertices[0];

					Renderer2D.DrawLine(float3(start.x, start.y, 0.0f), float3(end.x, end.y, 0.0f), *(ColorRGBA*)&color);
				};
			draw.drawCircleCallback = (center, radius, color, userData) =>
				{
					Renderer2D.DrawCircle(center, radius.XX, *(ColorRGBA*)&color, 0.1f);
				};
			draw.drawSolidCircleCallback = (center, radius, axis, color, userData) =>
				{
					Renderer2D.DrawCircle(center, radius.XX, *(ColorRGBA*)&color);
				};
			draw.drawSegmentCallback = (p1, p2, color, userData) =>
				{
				};
			draw.drawPointCallback = (p, size, color, userData) =>
				{
				};
			draw.drawTransformCallback = (xf, userData) =>
				{
				};
			draw.userData = Internal.UnsafeCastToPtr(_physicsWorld2D);

			World.SetDebugDraw(_physicsWorld2D, &draw);
			World.SetDebugDrawFlags(_physicsWorld2D, .e_shapeBit);

			InitPhysics2D();
		}

		private void SetupPhysicsCallbacks()
		{
			_contactListener = b2ContactListener();
			_contactListener.beginContactCallback = (contact, userData) =>
				{
					// TODO: This is bare minimum! Later we need to take hierarchies into account.
					// e.g. A is parent of B and B gets event -> A needs to get event too!

					var fixtureA = Contact.GetFixtureA(contact);
					var fixtureB = Contact.GetFixtureB(contact);

					var bodyA = Fixture.GetBody(fixtureA);
					var bodyB = Fixture.GetBody(fixtureB);

					// Cast is obviously 64bit only
					var colliderEntityHandleA = (EcsEntity)(uint)Fixture.GetUserData(fixtureA);
					var colliderEntityHandleB = (EcsEntity)(uint)Fixture.GetUserData(fixtureB);

					Entity colliderEntityA = .(colliderEntityHandleA, ScriptEngine.Context);
					Entity colliderEntityB = .(colliderEntityHandleB, ScriptEngine.Context);

					// Cast is obviously 64bit only
					var rigidbodyEntityHandleA = (EcsEntity)(uint)Body.GetUserData(bodyA);
					var rigidbodyEntityHandleB = (EcsEntity)(uint)Body.GetUserData(bodyB);

					Entity rigidbodyEntityA = .(rigidbodyEntityHandleA, ScriptEngine.Context);
					Entity rigidbodyEntityB = .(rigidbodyEntityHandleB, ScriptEngine.Context);

					bool fireEventA = colliderEntityA.TryGetComponent<ScriptComponent>(let scriptOfColliderA);
					fireEventA |= rigidbodyEntityA.TryGetComponent<ScriptComponent>(let scriptOfRigidbodyA);

					if (fireEventA)
					{
						Collision2D collision = .();
						collision.Entity = colliderEntityA.UUID;
						collision.OtherEntity = colliderEntityB.UUID;
						collision.Rigidbody = rigidbodyEntityA.UUID;
						collision.OtherRigidbody = rigidbodyEntityB.UUID;
						
						scriptOfColliderA?.Instance?.InvokeOnCollisionEnter2D(collision);
						scriptOfRigidbodyA?.Instance?.InvokeOnCollisionEnter2D(collision);
					}

					bool fireEventB = colliderEntityB.TryGetComponent<ScriptComponent>(let scriptOfColliderB);
					fireEventB |= rigidbodyEntityB.TryGetComponent<ScriptComponent>(let scriptOfRigidbodyB);
					
					if (fireEventB)
					{
						Collision2D collision = .();
						collision.Entity = colliderEntityB.UUID;
						collision.OtherEntity = colliderEntityA.UUID;
						collision.Rigidbody = rigidbodyEntityB.UUID;
						collision.OtherRigidbody = rigidbodyEntityA.UUID;
						
						scriptOfColliderB?.Instance?.InvokeOnCollisionEnter2D(collision);
						scriptOfRigidbodyB?.Instance?.InvokeOnCollisionEnter2D(collision);
					}
				};
			_contactListener.endContactCallback = (contact, userData) => {
				var fixtureA = Contact.GetFixtureA(contact);
				var fixtureB = Contact.GetFixtureB(contact);

				var bodyA = Fixture.GetBody(fixtureA);
				var bodyB = Fixture.GetBody(fixtureB);

				// Cast is obviously 64bit only
				var colliderEntityHandleA = (EcsEntity)(uint)Fixture.GetUserData(fixtureA);
				var colliderEntityHandleB = (EcsEntity)(uint)Fixture.GetUserData(fixtureB);

				Entity colliderEntityA = .(colliderEntityHandleA, ScriptEngine.Context);
				Entity colliderEntityB = .(colliderEntityHandleB, ScriptEngine.Context);

				// Cast is obviously 64bit only
				var rigidbodyEntityHandleA = (EcsEntity)(uint)Body.GetUserData(bodyA);
				var rigidbodyEntityHandleB = (EcsEntity)(uint)Body.GetUserData(bodyB);

				Entity rigidbodyEntityA = .(rigidbodyEntityHandleA, ScriptEngine.Context);
				Entity rigidbodyEntityB = .(rigidbodyEntityHandleB, ScriptEngine.Context);

				bool fireEventA = colliderEntityA.TryGetComponent<ScriptComponent>(let scriptOfColliderA);
				fireEventA |= rigidbodyEntityA.TryGetComponent<ScriptComponent>(let scriptOfRigidbodyA);

				if (fireEventA)
				{
					Collision2D collision = .();
					collision.Entity = colliderEntityA.UUID;
					collision.OtherEntity = colliderEntityB.UUID;
					collision.Rigidbody = rigidbodyEntityA.UUID;
					collision.OtherRigidbody = rigidbodyEntityB.UUID;
					
					scriptOfColliderA?.Instance?.InvokeOnCollisionLeave2D(collision);
					scriptOfRigidbodyA?.Instance?.InvokeOnCollisionLeave2D(collision);
				}

				bool fireEventB = colliderEntityB.TryGetComponent<ScriptComponent>(let scriptOfColliderB);
				fireEventB |= rigidbodyEntityB.TryGetComponent<ScriptComponent>(let scriptOfRigidbodyB);

				if (fireEventB)
				{
					Collision2D collision = .();
					collision.Entity = colliderEntityB.UUID;
					collision.OtherEntity = colliderEntityA.UUID;
					collision.Rigidbody = rigidbodyEntityB.UUID;
					collision.OtherRigidbody = rigidbodyEntityA.UUID;
					
					scriptOfColliderB?.Instance?.InvokeOnCollisionLeave2D(collision);
					scriptOfRigidbodyB?.Instance?.InvokeOnCollisionLeave2D(collision);
				}
			};

			World.SetContactListener(_physicsWorld2D, &_contactListener);
		}

		private void InitPhysics2D()
		{
			// Initialize all Rigidbodies
			for (let (ecsHandle, rigidBody) in _ecsWorld.Enumerate<Rigidbody2DComponent>())
			{
				Entity entity = .(ecsHandle, this);

				InitializeRigidbody2D(entity, rigidBody);
			}

			for (let (ecsHandle, boxCollider) in _ecsWorld.Enumerate<BoxCollider2DComponent>())
			{
				Entity entity = .(ecsHandle, this);

				InitBoxCollider2D(entity, boxCollider);
			}

			for (let (ecsHandle, circleCollider) in _ecsWorld.Enumerate<CircleCollider2DComponent>())
			{
				Entity entity = .(ecsHandle, this);

				InitCircleCollider2D(entity, circleCollider);
			}

			for (let (ecsHandle, polygonCollider) in _ecsWorld.Enumerate<PolygonCollider2DComponent>())
			{
				Entity entity = .(ecsHandle, this);

				InitPolygonCollider2D(entity, polygonCollider);
			}
		}

		private void InitializeRigidbody2D(Entity entity, Rigidbody2DComponent* rigidBody)
		{
			var transform = entity.Transform;

			b2BodyDef def = .();
			def.type = GetBox2DBodyType(rigidBody.BodyType);
			def.userData = (void*)(uint)entity.Handle;

			// TODO: check how stable this is
			Matrix.Decompose(transform.WorldTransform, let worldPosition, let worldRotation, let worldScale);
			float3 worldRotationEuler = Quaternion.ToEulerAngles(worldRotation);

			def.position = b2Vec2(worldPosition.X, worldPosition.Y);
			def.angle = worldRotationEuler.Z;

			b2Body* body = Box2D.World.CreateBody(_physicsWorld2D, &def);
			Box2D.Body.SetFixedRotation(body, rigidBody.FixedRotation);

			rigidBody.RuntimeBody = body;
		}

		private Result<void> FindParentWithRigidbody(Entity entity, out Entity walker, out Rigidbody2DComponent* rigidbody, out Matrix rigidbodyTransform)
		{
			walker = entity;
			rigidbody = null;
			rigidbodyTransform = .Identity;

			while (true)
			{
				// Found the parent with our beloved component
				if (walker.TryGetComponent<Rigidbody2DComponent>(out rigidbody) == true)
					break;

				let parent = walker.Parent;

				// We need a rigid body
				if (parent == null)
				{
					Log.ClientLogger.Warning($"Entity {entity.Name} ({entity.Handle}) has a collider but no parent with a rigid body!");
					return .Err;
				}
				
				// Construct transform matrix from our local space to the rigidbody space
				rigidbodyTransform = rigidbodyTransform * walker.Transform.LocalTransform;

				walker = parent.Value;
			}

			return .Ok;
		}

		private void InitBoxCollider2D(Entity entity, BoxCollider2DComponent* boxCollider)
		{
			if (FindParentWithRigidbody(entity, let entityWithRigidbody, let rigidbody, let parentToRigidbody) case .Err)
				return;

			let localToWorld = entity.Transform.WorldTransform;
			let worldToRigidbody = entityWithRigidbody.Transform.WorldTransform.Invert();

			Box2D.b2Vec2[4] points = .(
				.(-1, -1),
				.( 1, -1),
				.( 1,  1),
				.(-1,  1));

			for (int i < 4)
			{
				points[i] = ((float2)points[i] * boxCollider.Size + boxCollider.Offset);

				if (entity == entityWithRigidbody)
					 points[i] = entity.Transform.Scale.XY * (float2)points[i];

				points[i] = (worldToRigidbody * localToWorld * float4(points[i], 0, 1)).XY;
			}

			let boxShape = Box2D.Shape.CreatePolygon();
			Shape.PolygonSet(boxShape, &points, 4);

			b2FixtureDef fixtureDef = .();
			fixtureDef.shape = boxShape;
			fixtureDef.density = boxCollider.Density;
			fixtureDef.friction = boxCollider.Friction;
			fixtureDef.restitution = boxCollider.Restitution;
			fixtureDef.restitutionThreshold = boxCollider.RestitutionThreshold;
			fixtureDef.userData = (void*)(uint)entity.Handle;

			Log.EngineLogger.AssertDebug(rigidbody.RuntimeBody != null);
			b2Fixture* fixture = Box2D.Body.CreateFixture(rigidbody.RuntimeBody, &fixtureDef);
			boxCollider.RuntimeFixture = fixture;
		}

		private void InitCircleCollider2D(Entity entity, CircleCollider2DComponent* circleCollider)
		{
			if (FindParentWithRigidbody(entity, let entityWithRigidbody, let rigidbody, let parentToRigidbody) case .Err)
				return;

			let localToWorld = entity.Transform.WorldTransform;
			let worldToRigidbody = entityWithRigidbody.Transform.WorldTransform.Invert();

			b2Vec2 center = (worldToRigidbody * localToWorld * float4(circleCollider.b2Offset, 0, 1)).XY;

			b2Shape* circleShape = Box2D.Shape.CreateCircle();
			Box2D.Shape.CircleSetPosition(circleShape, center);
			Box2D.Shape.SetRadius(circleShape, circleCollider.Radius);

			b2FixtureDef fixtureDef = .();
			fixtureDef.shape = circleShape;
			fixtureDef.density = circleCollider.Density;
			fixtureDef.friction = circleCollider.Friction;
			fixtureDef.restitution = circleCollider.Restitution;
			fixtureDef.restitutionThreshold = circleCollider.RestitutionThreshold;
			fixtureDef.userData = (void*)(uint)entity.Handle;

			Log.EngineLogger.AssertDebug(rigidbody.RuntimeBody != null);
			b2Fixture* fixture = Box2D.Body.CreateFixture(rigidbody.RuntimeBody, &fixtureDef);
			circleCollider.RuntimeFixture = fixture;
		}

		private void InitPolygonCollider2D(Entity entity, PolygonCollider2DComponent* polygonCollider)
		{
			if (FindParentWithRigidbody(entity, let entityWithRigidbody, let rigidbody, let parentToRigidbody) case .Err)
				return;

			let localToWorld = entity.Transform.WorldTransform;
			let worldToRigidbody = entityWithRigidbody.Transform.WorldTransform.Invert();

			Box2D.b2Vec2[8] points = .();

			for (int i < polygonCollider.VertexCount)
			{
				points[i] = ((float2)polygonCollider.Vertices[i] + polygonCollider.Offset);

				if (entity == entityWithRigidbody)
					 points[i] = entity.Transform.Scale.XY * (float2)points[i];

				points[i] = (worldToRigidbody * localToWorld * float4(points[i], 0, 1)).XY;
			}
			
			let polygonShape = Box2D.Shape.CreatePolygon();
			Shape.PolygonSet(polygonShape, &points, polygonCollider.VertexCount);

			b2FixtureDef fixtureDef = .();
			fixtureDef.shape = polygonShape;
			fixtureDef.density = polygonCollider.Density;
			fixtureDef.friction = polygonCollider.Friction;
			fixtureDef.restitution = polygonCollider.Restitution;
			fixtureDef.restitutionThreshold = polygonCollider.RestitutionThreshold;
			fixtureDef.userData = (void*)(uint)entity.Handle;

			Log.EngineLogger.AssertDebug(rigidbody.RuntimeBody != null);
			b2Fixture* fixture = Box2D.Body.CreateFixture(rigidbody.RuntimeBody, &fixtureDef);
			polygonCollider.RuntimeFixture = fixture;
		}

		private void StopSimulation()
		{
			if (_physicsWorld2D == null)
				return;

			Box2D.World.Delete(_physicsWorld2D);
			_physicsWorld2D = null;

			// TODO: Get rid of all references to colliders, etc. in physics components.
		}

		public enum UpdateMode
		{
			/// No special update configuration (this does NOT mean nothing will be updated!)
			None = 0x00,
			/// Update the physics related stuff
			Physics = 0x01,
			/// Execute scripts.
			Scripts = 0x02,
			/// Update editor-specific stuff
			EditMode = 0x04,
			/// Update editor-specific stuff and also scripts (most only ever initialize, but some update!)
			/// Update the runtume related stuff (e.g. execute scripts). Also run physics!
			//RuntimeMode = Scripts | Physics,
		}

		private append List<Entity> _destroyQueue = .();

		private append List<ScriptInstance> _destroyScriptQueue = .();

		float physicsDelta = 0;

		private void UpdatePhysics(GameTime gameTime)
		{
			physicsDelta += gameTime.DeltaTime;
			
			while (physicsDelta > _fixedDeltaTime)
			{
				physicsDelta -= _fixedDeltaTime;

				Debug.Profiler.ProfileScope!("2D Physics Iteration");

				Box2D.World.Step(_physicsWorld2D, _fixedDeltaTime, Physics2DSettings.VelocityIterations, Physics2DSettings.PositionIterations, Physics2DSettings.ParticleIterations);
	
				// Retrieve transform from Box2D
				for (var entry in _ecsWorld.Enumerate<Rigidbody2DComponent>())
				{
					Entity entity = .(entry.Entity, this);
	
					var transform = entity.Transform;
					var rigidbody = entry.Component;
	
					b2Body* body = rigidbody.RuntimeBody;
					b2Vec2 position = Box2D.Body.GetPosition(body);
					float angle = Box2D.Body.GetAngle(body);
					b2Transform bodyTransform = Box2D.Body.GetTransform(body);
	
					float cos = sqrt((1 + bodyTransform.q.c) / 2);
					float sin = sqrt((1 - bodyTransform.q.c) / 2) * sign(bodyTransform.q.s);
	
					Quaternion rotation = .(0, 0, sin, cos)..Normalize();
					
					if (entity.Parent != null)
					{
						Matrix worldToParent = entity.Parent.Value.Transform.WorldTransform.Invert();
	
						float4 newLocalPosition = worldToParent * float4(position, 0, 1);
						transform.Position = float3(newLocalPosition.XY, transform.Position.Z);
	
						// TODO: when the parent of the rigidbody-entity is rotated, the rotation is applied wrong...
						Matrix.Decompose(worldToParent, let p, var worldToParentRotation, let s);
						//Quaternion newLocalRotation = (worldToParentRotation..Normalize() * rotation..Normalize())..Normalize();
						//Quaternion newLocalRotation = (rotation * worldToParentRotation..Normalize())..Normalize();
						//Quaternion newLocalRotation = (worldToParentRotation * rotation)..Normalize();
						Quaternion newLocalRotation = rotation..Normalize();
						//Quaternion newLocalRotation = Quaternion.FromEulerAngles(0, 0, angle)..Normalize();
						// TODO: when the parent has rotation on X or Y everything breaks even more...
						//transform.Rotation = (Quaternion.FromEulerAngles(transform.RotationEuler.Y, transform.RotationEuler.X, 0)..Normalize() * newLocalRotation)..Normalize();//(newLocalRotation * Quaternion.FromEulerAngles(transform.RotationEuler.Y, transform.RotationEuler.X, 0))..Normalize();
						//transform.Rotation = ((transform.Rotation..Normalize() * Quaternion.FromEulerAngles(0, 0, transform.RotationEuler.Z)..Normalize())..Normalize() * newLocalRotation)..Normalize();//(newLocalRotation * Quaternion.FromEulerAngles(transform.RotationEuler.Y, transform.RotationEuler.X, 0))..Normalize();
						transform.Rotation = (newLocalRotation)..Normalize();//(newLocalRotation * Quaternion.FromEulerAngles(transform.RotationEuler.Y, transform.RotationEuler.X, 0))..Normalize();
					}
					else
					{
						transform.Position = .(position.x, position.y, transform.Position.Z);
						transform.Rotation = rotation;
					}
				}

				// TODO: Execute Fixed-Updates
			}
		}

		private void UpdateScripts(GameTime gameTime, UpdateMode mode)
		{
			Debug.Profiler.ProfileScope!("Update scripts");

			// all OnCreates have to be executed before the first OnUpdate!

			// TODO: This could also be handled with a queue!
			// Init and OnCreate
			for (let (entity, script) in _ecsWorld.Enumerate<ScriptComponent>())
			{
				if (script.IsCreated)
					continue;

				if (!script.IsInitialized)
					ScriptEngine.InitializeInstance(Entity(entity, this), script);
				
				// Skip OnCreate and OnUpdate invocation if we didn't create an instance
				// (happens, if script component has no script class associated)
				// Also skip if we are in edit mode and the class doesn't have the RunInEditMode-Attribute
				if (script.Instance == null || (mode.HasFlag(.EditMode) && !script.Instance.ScriptClass.RunInEditMode))
					continue;

				script.Instance.InvokeOnCreate();
			}

			// OnUpdate
			for (let (entity, script) in _ecsWorld.Enumerate<ScriptComponent>())
			{
				if (script.Instance == null)
					continue;

				// TODO: When the entity is destroyed in OnCreate it's OnUpdate will still be called. Is this fine?
				// It would require that we somehow track whether the entity is to be deleted. We technically have this info but would probably need
				// some faster way. If we for some reason ever happen to implement such a fast way we can check for planned deletion here (or after on Create and just continue;).

				// Update the script, if we aren't in editor or it has RunInEditMode-Attribute
				if (!mode.HasFlag(.EditMode) || script.Instance.ScriptClass.RunInEditMode)
				{
					if (_updateBlockList.Contains(entity))
						_updateBlockList.Remove(entity);
					else
						script.Instance.InvokeOnUpdate(gameTime.DeltaTime);
				}
			}
		}

		public void Update(GameTime gameTime, UpdateMode mode)
		{
			Debug.Profiler.ProfileRendererFunction!();

			TransformSystem.Update(_ecsWorld);

			if (mode.HasFlag(.Scripts))
			{
				UpdateScripts(gameTime, mode);
			}

			if (!_destroyScriptQueue.IsEmpty)
			{
				for (let scriptInstance in _destroyScriptQueue)
				{
					scriptInstance.ReleaseRef();

					Log.EngineLogger.AssertDebug(scriptInstance.RefCount == 1, "Too many references to script instance. Did we leak it?");

					ScriptEngine.DestroyInstance(scriptInstance.EntityId);
				}

				_destroyScriptQueue.Clear();
			}

			if (!_destroyQueue.IsEmpty)
			{
				for (let entity in _destroyQueue)
				{
					DestroyEntity(entity);
				}

				_destroyQueue.Clear();
			}

			if (mode.HasFlag(.Physics))
			{
				UpdatePhysics(gameTime);
			}
		}

		/// Creates a new Entity with the given name.
		public Entity CreateEntity(StringView name = "", UUID id = default)
		{
			Entity entity = Entity(_ecsWorld.NewEntity(), this);
			entity.AddComponent<TransformComponent>();

			let nameComponent = entity.AddComponent<NameComponent>();
			nameComponent.Name = (name.IsEmpty ? "Entity" : name);
			
			// If no id is given generate a random one.
			IDComponent idComponent = (id == default) ? IDComponent() : IDComponent(id);

			entity.AddComponent<IDComponent>(idComponent);

			_idToEntity.Add(idComponent.ID, entity.Handle);

			return entity;
		}

		/** Deletes the given entity.
		 * @param entity The entity to delete.
		 * @param destroyChildren If set to true all children of entity will be destroyed.
		*/
		public void DestroyEntity(Entity entity, bool destroyChildren = false)
		{
			_idToEntity.Remove(entity.UUID);
			
			ScriptEngine.DestroyInstance(entity.UUID);

			if (destroyChildren)
			{
				for (Entity child in entity.EnumerateChildren)
				{
					DestroyEntity(child, true);
				}
			}
			
			_ecsWorld.RemoveEntity(entity.Handle);
		}
		
		/** Marks the given entity and it's children, so that they will be destroyed at the end of the frame.
		 * @param entity The entity to delete.
		 */
		public void DestroyEntityDeferred(Entity entity)
		{
			_destroyQueue.Add(entity);

			for (Entity child in entity.EnumerateChildren)
			{
				DestroyEntityDeferred(child);
			}
		}

		/**
		 * Marks the given scriptInstance so that it will be deleted at the end of the update-loop. 
		 * @param scriptInstance The script instance to destroy.
		 * @param removeComponent If set to true the ScriptComponent will be removed from the entity.
		 */
		public void DestroyScriptDeferred(ScriptInstance scriptInstance, bool removeComponent)
		{
			_destroyScriptQueue.Add(scriptInstance..AddRef());

			if (removeComponent)
			{
				Result<Entity> foundEntity = GetEntityByID(scriptInstance.EntityId);

				Log.EngineLogger.AssertDebug(foundEntity case .Ok, "DestroyScriptDeferred: Could not find entity.");

				if (foundEntity case .Ok(let entity))
				{
					entity.RemoveComponent<ScriptComponent>();
				}
			}
		}

		/** Creates a copy of the given entity, including all components and children.
		 * @param entity the entity to copy.
		 * @returns the newly create entity.
		 */
		public Entity CreateInstance(Entity entity)
		{
			Dictionary<UUID, SerializedObject> serializedData = scope .();
			defer { ClearDictionaryAndDeleteValues!(serializedData); }

			List<Entity> newEntities = scope .();
			Dictionary<EcsEntity, EcsEntity> sourceToTargetEntity = scope .();
			Dictionary<UUID, UUID> sourceIdToTargetId = scope .();
			Dictionary<UUID, Entity> targetIdToSourceEntity = scope .();
			List<(UUID oldId, ScriptInstance scriptInstance)> newScripts = scope .();
			
			Entity CopyEntityAndChildren(Entity original, Entity? copyParent)
			{
				Entity copy = CreateEntity(original.Name);
				copy.Parent = copyParent;

				newEntities.Add(copy);
				sourceToTargetEntity.Add(original.Handle, copy.Handle);
				sourceIdToTargetId.Add(original.UUID, copy.UUID);
				targetIdToSourceEntity.Add(copy.UUID, original);
				_updateBlockList.Add(copy.Handle);

				CopyComponent<MeshRendererComponent>(original, copy);
				CopyComponent<MeshComponent>(original, copy);
				CopyComponent<EditorComponent>(original, copy);
				CopyComponent<SpriteRendererComponent>(original, copy);
				CopyComponent<CircleRendererComponent>(original, copy);
				CopyComponent<CameraComponent>(original, copy);
				CopyComponent<LightComponent>(original, copy);

				CopyComponent<Rigidbody2DComponent>(original, copy);
				CopyComponent<BoxCollider2DComponent>(original, copy);
				CopyComponent<CircleCollider2DComponent>(original, copy);
				CopyComponent<PolygonCollider2DComponent>(original, copy);

				// Copy ScriptComponent... needs extra handling for the script instances
				if (original.TryGetComponent<ScriptComponent>(let sourceScript))
				{
					ScriptComponent* targetScript = copy.AddComponent<ScriptComponent>();
					
					targetScript.ScriptClassName = sourceScript.ScriptClassName;

					if (sourceScript.Instance != null)
					{
						ScriptEngine.SerializeScriptInstance(sourceScript.Instance, serializedData);
						
						// Initializes the created instance
						// TODO: this returns false, if no script with ScriptClassName exists, we have to handle this case correctly I think.
						ScriptEngine.InitializeInstance(copy, targetScript);
						
						newScripts.Add((original.UUID, targetScript.Instance));
					}
				}

				// This is kinda slow because it's in O(n*m) where n is the tree depth and m is the total number of entities in the scene...
				for (let child in original.EnumerateChildren)
				{
					CopyEntityAndChildren(child, copy);
				}

				return copy;
			}

			Entity newEntity = CopyEntityAndChildren(entity, null);

			// Replace old IDs with new ones
			ScriptEngine.FixupSerializedIds(sourceIdToTargetId, serializedData);

			// Use separate loops for deserialization and OnCreate to ensure complete entities and references in OnCreate

			for (let (originalId, newScriptInstance) in newScripts)
			{
				ScriptEngine.DeserializeScriptInstance(originalId, newScriptInstance, serializedData);
			}

			for (let (_, newScriptInstance) in newScripts)
			{
				if (ScriptEngine.ApplicationInfo.IsInPlayMode || newScriptInstance.ScriptClass.RunInEditMode)
					newScriptInstance.InvokeOnCreate();
			}

			return newEntity;
		}

		public Result<Entity> GetEntityByID(UUID id)
		{
			if (_idToEntity.TryGetValue(id, let ecsEntity))
			{
				return .Ok(Entity(ecsEntity, this));
			}

			return .Err;
		}

		public Result<Entity> GetEntityByName(StringView name)
		{
			for (let (ecsEntity, nameComponent) in GetEntities<NameComponent>())
			{
				if (nameComponent.Name == name)
					return .Ok(Entity(ecsEntity, this));
			}

			return .Err;
		}

		/// Sets the size of the viewport into which the scene will be rendered.
		public void SetViewportSize(uint32 width, uint32 height)
		{
			if (_viewportWidth == width && _viewportHeight == height)
				return;

			_viewportWidth = width;
			_viewportHeight = height;

			for (var (entity, cameraComponent) in _ecsWorld.Enumerate<CameraComponent>())
			{
				if (!cameraComponent.Camera.FixedAspectRatio)
				{
					cameraComponent.Camera.SetViewportSize(width, height);
				}
			}
		}

		private void OnComponentAdded(Entity entity, Type componentType, void* component)
		{
			if (_onComponentAddedHandlers.TryGetValue(componentType, let handler))
			{
				handler(entity, componentType, component);
			}
		}

		private void OnComponentRemoved(Entity entity, Type componentType, void* component)
		{
			if (_onComponentAddedHandlers.TryGetValue(componentType, let handler))
			{
				handler(entity, componentType, component);
			}
		}

		public WorldEnumerator<TComponent> GetEntities<TComponent>() where TComponent : struct
		{
			return _ecsWorld.Enumerate<TComponent>();
		}

		public WorldEnumerator<TComponent1, TComponent2> GetEntities<TComponent1, TComponent2>()
			where TComponent1 : struct
			where TComponent2 : struct
		{
			return _ecsWorld.Enumerate<TComponent1, TComponent2>();
		}

		public WorldEnumerator<TComponent1, TComponent2, TComponent3> GetEntities<TComponent1, TComponent2, TComponent3>()
			where TComponent1 : struct
			where TComponent2 : struct
			where TComponent3 : struct
		{
			return _ecsWorld.Enumerate<TComponent1, TComponent2, TComponent3>();
		}
	}
}

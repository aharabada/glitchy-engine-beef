using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;
using System.Collections;
using Box2D;
using GlitchyEngine.Core;
using GlitchyEngine.Content;
using GlitchyEngine.Scripting;

namespace GlitchyEngine.World
{
	using internal ScriptableEntity;
	using internal GlitchyEngine.World;

	class Scene : RefCounter
	{
		internal EcsWorld _ecsWorld = new .() ~ delete _;

		internal b2World* _physicsWorld2D;

		private Dictionary<Type, function void(Entity entity, Type componentType, void* component)> _onComponentAddedHandlers = new .() ~ delete _;

		private uint32 _viewportWidth, _viewportHeight;

		// Maps ids to the entities they represent.
		private Dictionary<UUID, EcsEntity> _idToEntity = new .() ~ delete _;

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

		public this()
		{
			_onComponentAddedHandlers.Add(typeof(CameraComponent), (e, t, c) => {
				CameraComponent* cameraComponent = (.)c;

				cameraComponent.Camera.SetViewportSize(e.Scene._viewportWidth, e.Scene._viewportHeight);
			});

			/*_onComponentAddedHandlers.Add(typeof(Rigidbody2DComponent), (e, t, c) => {
				if ()


				Rigidbody2DComponent* rigidBodyComponent = (.)c;

				//cameraComponent.Camera.SetViewportSize(e.Scene._viewportWidth, e.Scene._viewportHeight);
			});*/
		}

		public ~this()
		{
		}

		public void CopyTo(Scene target)
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
			CopyComponents<NativeScriptComponent>(this, target);
			CopyComponents<LightComponent>(this, target);
			CopyComponents<Rigidbody2DComponent>(this, target);
			CopyComponents<BoxCollider2DComponent>(this, target);
			CopyComponents<CircleCollider2DComponent>(this, target);

			// Copy ScriptComponents... needs extra handling for the script instances
			for (let (sourceHandle, sourceComponent) in _ecsWorld.Enumerate<ScriptComponent>())
			{
				Entity sourceEntity = .(sourceHandle, this);

				Entity targetEntity = target.GetEntityByID(sourceEntity.UUID);
				ScriptComponent* targetComponent = targetEntity.AddComponent<ScriptComponent>();
				
				targetComponent.ScriptClassName = sourceComponent.ScriptClassName;

				// Initializes the created instance
				// TODO: this returns false, if no script with ScriptClassName exists, we have to handle this case correctly I think.
				ScriptEngine.InitializeInstance(targetEntity, targetComponent);
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
		
		b2Vec2 _gravity2D = .(0.0f, -9.8f);

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

		public void OnRuntimeStart()
		{
			OnSimulationStart();
			ScriptEngine.SetContext(this);
		}

		public void OnRuntimeStop()
		{
			OnSimulationStop();
			ScriptEngine.OnRuntimeStop();
		}
		
		public void OnSimulationStart()
		{
			_physicsWorld2D = Box2D.World.Create(ref _gravity2D);

			for (let (ecsHandle, rigidBody) in _ecsWorld.Enumerate<Rigidbody2DComponent>())
			{
				Entity entity = .(ecsHandle, this);

				InitializeRigidbody2D(entity, rigidBody);
			}
		}

		private void InitializeRigidbody2D(Entity entity, Rigidbody2DComponent* rigidBody)
		{
			var transform = entity.Transform;

			b2BodyDef def = .();
			def.type = GetBox2DBodyType(rigidBody.BodyType);

			// TODO: breaks with hierarchy
			def.position = b2Vec2(transform.Position.X, transform.Position.Y);
			def.angle = transform.RotationEuler.Z;

			b2Body* body = Box2D.World.CreateBody(_physicsWorld2D, &def);
			Box2D.Body.SetFixedRotation(body, rigidBody.FixedRotation);

			rigidBody.RuntimeBody = body;

			if (entity.TryGetComponent<BoxCollider2DComponent>(let boxCollider))
			{
				b2Shape* boxShape = Box2D.Shape.CreatePolygon();
				Box2D.Shape.PolygonSetAsBox(boxShape, boxCollider.Size.X * transform.Scale.X, boxCollider.Size.Y * transform.Scale.Y);
				Box2D.Shape.PolygonSetAsBoxWithCenterAngle(boxShape, boxCollider.Size.X * transform.Scale.X, boxCollider.Size.Y * transform.Scale.Y, ref boxCollider.b2Offset, 0.0f);

				b2FixtureDef fixtureDef = .();
				fixtureDef.shape = boxShape;
				fixtureDef.density = boxCollider.Density;
				fixtureDef.friction = boxCollider.Friction;
				fixtureDef.restitution = boxCollider.Restitution;
				fixtureDef.restitutionThreshold = boxCollider.RestitutionThreshold;

				b2Fixture* fixture = Box2D.Body.CreateFixture(body, &fixtureDef);
				boxCollider.RuntimeFixture = fixture;
			}

			if (entity.TryGetComponent<CircleCollider2DComponent>(let circleCollider))
			{
				b2Shape* circleShape = Box2D.Shape.CreateCircle();
				Box2D.Shape.CircleSetPosition(circleShape, ref circleCollider.b2Offset);
				Box2D.Shape.SetRadius(circleShape, circleCollider.Radius);

				b2FixtureDef fixtureDef = .();
				fixtureDef.shape = circleShape;
				fixtureDef.density = circleCollider.Density;
				fixtureDef.friction = circleCollider.Friction;
				fixtureDef.restitution = circleCollider.Restitution;
				fixtureDef.restitutionThreshold = circleCollider.RestitutionThreshold;

				b2Fixture* fixture = Box2D.Body.CreateFixture(body, &fixtureDef);
				circleCollider.RuntimeFixture = fixture;
			}
		}

		public void OnSimulationStop()
		{
			Box2D.World.Delete(_physicsWorld2D);
			_physicsWorld2D = null;
		}

		public enum UpdateMode
		{
			/// No special update configuration (this does NOT mean nothing will be updated!)
			None = 0x00,
			/// Update editor-specific stuff
			Editor = 0x01,
			/// Update the physics related stuff
			Physics = 0x02,
			/// Update the runtume related stuff (e.g. execute scripts). Also run physics!
			Runtime = 0x04 | Physics,
		}

		//private append List<UUID> _destroyQueue = .();

		public void Update(GameTime gameTime, UpdateMode mode)
		{
			Debug.Profiler.ProfileRendererFunction!();

			TransformSystem.Update(_ecsWorld);

			if (mode.HasFlag(.Runtime))
			{
				// Run scripts
				for (var (entity, script) in _ecsWorld.Enumerate<NativeScriptComponent>())
				{
					if (script.Instance == null)
					{
						script.Instance = script.InstantiateFunction();
						script.Instance._entity = Entity(entity, this);
						script.Instance.[Friend]OnCreate();
					}
	
					script.Instance.[Friend]OnUpdate(gameTime);
				}
			/*}
			
			if (mode.HasFlag(.Runtime) || mode.HasFlag(.Editor))
			{*/
				// Run scripts
				for (var (entity, script) in _ecsWorld.Enumerate<ScriptComponent>())
				{
					if (!script.IsCreated)
					{
						if (!script.IsInitialized)
							ScriptEngine.InitializeInstance(Entity(entity, this), script);

						if (mode.HasFlag(.Runtime))
							script.Instance.InvokeOnCreate();
					}
					
					if (mode.HasFlag(.Runtime))
						script.Instance.InvokeOnUpdate(gameTime.DeltaTime);
				}
			}

			/*if (mode.HasFlag(.Editor))
			{
				// Run editor scripts
				for (var (entity, script) in _ecsWorld.Enumerate<ScriptComponent>())
				{
					if (!script.InInstantiated)
					{
						ScriptEngine.InitializeInstance(Entity(entity, this), script);
					}

					// TODO: Editor update
					//script.Instance.InvokeOnUpdate(gameTime.DeltaTime);
				}
			}*/
			
			if (mode.HasFlag(.Physics))
			{
				// Update 2D physics
				{
					const int32 velocityIterations = 6;
					const int32 positionIterations = 2;
					const int32 particleIterations = 2;

					Box2D.World.Step(_physicsWorld2D, gameTime.DeltaTime, velocityIterations, positionIterations, particleIterations);

					// Retrieve transform from Box2D
					for (var entry in _ecsWorld.Enumerate<Rigidbody2DComponent>())
					{
						Entity entity = .(entry.Entity, this);

						var transform = entity.Transform;
						var rigidbody = entry.Component;

						b2Body* body = rigidbody.RuntimeBody;
						b2Vec2 position = Box2D.Body.GetPosition(body);
						float angle = Box2D.Body.GetAngle(body);

						transform.Position = .(position.x, position.y, transform.Position.Z);
						transform.RotationEuler = .(transform.RotationEuler.XY, angle);
					}
				}
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

			if (destroyChildren)
			{
				for (Entity child in entity.EnumerateChildren)
				{
					DestroyEntity(child, true);
				}
			}
			
			_ecsWorld.RemoveEntity(entity.Handle);
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

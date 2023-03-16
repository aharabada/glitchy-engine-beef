using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;
using System.Collections;
using Box2D;
using GlitchyEngine.Core;
using GlitchyEngine.Content;

namespace GlitchyEngine.World
{
	using internal ScriptableEntity;
	using internal GlitchyEngine.World;

	class Scene
	{
		internal EcsWorld _ecsWorld = new .() ~ delete _;

		internal b2World* _physicsWorld2D;

		private Dictionary<Type, function void(Entity entity, Type componentType, void* component)> _onComponentAddedHandlers = new .() ~ delete _;

		private RenderTargetGroup _compositeTarget ~ _.ReleaseRef();

		// Temporary target for camera. Needs to change as soon as we support multiple cameras
		private RenderTargetGroup _cameraTarget ~ _.ReleaseRef();

		private AssetHandle _gammaCorrectEffect;

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
			/*Entity entity = CreateEntity("Green Quad");
			entity.AddComponent<SpriterRendererComponent>(.(ColorRGBA.SRgbToLinear(.(0.2f, 0.9f, 0.15f))));

			Entity entity2 = CreateEntity("Red Square");
			var v = entity2.AddComponent<SpriterRendererComponent>(.(ColorRGBA.SRgbToLinear(.(0.95f, 0.1f, 0.3f))));
			v.Sprite = new Texture2D("Textures/rocket.dds");
			v.Sprite.SamplerState = SamplerStateManager.PointClamp;*/

			_onComponentAddedHandlers.Add(typeof(CameraComponent), (e, t, c) => {
				CameraComponent* cameraComponent = (.)c;

				cameraComponent.Camera.SetViewportSize(e.Scene.ViewportWidth, e.Scene.ViewportHeight);
			});

			RenderTargetGroupDescription desc = .(100, 100,
				TargetDescription[](
				RenderTargetFormat.R16G16B16A16_Float,
				.(RenderTargetFormat.R32_UInt) {ClearColor = .UInt(uint32.MaxValue)}),
				RenderTargetFormat.D24_UNorm_S8_UInt);
			_compositeTarget = new RenderTargetGroup(desc);

			_cameraTarget = new RenderTargetGroup(.(){
					Width = 100,
					Height = 100,
					ColorTargetDescriptions = TargetDescription[](
						.(.R16G16B16A16_Float),
						.(.R32_UInt)
					),
					DepthTargetDescription = .(.D24_UNorm_S8_UInt)
				});

			_gammaCorrectEffect = Content.LoadAsset("Shaders/GammaCorrect.hlsl");//Application.Get().EffectLibrary.Load("content/Shaders/GammaCorrect.hlsl");
		}

		public ~this()
		{
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
			_physicsWorld2D = Box2D.World.Create(ref _gravity2D);

			for (var entry in _ecsWorld.Enumerate<Rigidbody2DComponent>())
			{
				Entity entity = .(entry.Entity, this);

				var transform = entity.Transform;
				var rigidBody = entry.Component;

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
		}

		public void OnRuntimeStop()
		{
			Box2D.World.Delete(_physicsWorld2D);
			_physicsWorld2D = null;
		}

		public void UpdateRuntime(GameTime gameTime, RenderTargetGroup finalTarget)
		{
			Debug.Profiler.ProfileRendererFunction!();

			finalTarget.AddRef();
			
			TransformSystem.Update(_ecsWorld);

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

			// Find camera
			Camera* primaryCamera = null;
			Matrix primaryCameraTransform = default;
			RenderTargetGroup renderTarget = null;

			for (var (entity, transform, camera) in _ecsWorld.Enumerate<TransformComponent, CameraComponent>())
			{
				if (camera.Primary)// && camera.RenderTarget != null)
				{
					primaryCamera = &camera.Camera;
					primaryCameraTransform = transform.WorldTransform;
					// TODO: bind render targets to cameras
					// renderTarget = camera.RenderTarget..AddRef();
				}
			}

			renderTarget = _cameraTarget..AddRef();

			// 3D render
			Renderer.BeginScene(*primaryCamera, primaryCameraTransform, renderTarget, _compositeTarget);

			for (var (entity, transform, mesh, meshRenderer) in _ecsWorld.Enumerate<TransformComponent, MeshComponent, MeshRendererComponent>())
			{
				Renderer.Submit(mesh.Mesh, meshRenderer.Material, entity, transform.WorldTransform);
			}

			for (var (entity, transform, light) in _ecsWorld.Enumerate<TransformComponent, LightComponent>())
			{
				Renderer.Submit(light.SceneLight, transform.WorldTransform);
			}

			Renderer.EndScene();

			renderTarget.ReleaseRef();

			// TODO: alphablending (handle in Renderer2D)
			// TODO: 2D-Postprocessing requires rendering into separate target instead of directly into compositeTarget

			RenderCommand.SetRenderTargetGroup(_compositeTarget);
			RenderCommand.BindRenderTargets();

			// Sprite renderer
			Renderer2D.BeginScene(*primaryCamera, primaryCameraTransform, .BackToFront);

			for (var (entity, transform, sprite) in _ecsWorld.Enumerate<TransformComponent, SpriterRendererComponent>())
			{
				Renderer2D.DrawSprite(transform.WorldTransform, sprite, entity.Index);
			}

			Renderer2D.EndScene();

			// Gamma correct composit target and draw it into viewport
			{
				RenderCommand.UnbindRenderTargets();
				RenderCommand.SetRenderTargetGroup(finalTarget, false);
				RenderCommand.BindRenderTargets();

				Effect gammaEffect = Content.GetAsset<Effect>(_gammaCorrectEffect);

				gammaEffect.SetTexture("Texture", _compositeTarget, 0);
				// TODO: iiihhh
				gammaEffect.ApplyChanges();
				gammaEffect.Bind();
	
				FullscreenQuad.Draw();
			}

			finalTarget.ReleaseRef();


			/*Debug.Profiler.ProfileRendererFunction!();

			finalTarget.AddRef();

			TransformSystem.Update(_ecsWorld);

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

			// Find camera
			Camera* primaryCamera = null;
			Matrix primaryCameraTransform = default;
			RenderTargetGroup renderTarget = null;

			for (var (entity, transform, camera) in _ecsWorld.Enumerate<TransformComponent, CameraComponent>())
			{
				if (camera.Primary)// && camera.RenderTarget != null)
				{
					primaryCamera = &camera.Camera;
					primaryCameraTransform = transform.WorldTransform;
					//renderTarget = camera.RenderTarget..AddRef();
				}
			}

			if (primaryCamera != null)
			{
				// 3D render
				Renderer.BeginScene(*primaryCamera, primaryCameraTransform, _compositeTarget, finalTarget);
	
				for (var (entity, transform, mesh, meshRenderer) in _ecsWorld.Enumerate<TransformComponent, MeshComponent, MeshRendererComponent>())
				{
					Renderer.Submit(mesh.Mesh, meshRenderer.Material, entity, transform.WorldTransform);
				}
	
				for (var (entity, transform, light) in _ecsWorld.Enumerate<TransformComponent, LightComponent>())
				{
					Renderer.Submit(light.SceneLight, transform.WorldTransform);
				}
	
				Renderer.EndScene();
	
				// TODO: alphablending (handle in Renderer2D)
				// TODO: 2D-Postprocessing requires rendering into separate target instead of directly into compositeTarget
	
				RenderCommand.SetRenderTargetGroup(_compositeTarget);
				RenderCommand.BindRenderTargets();
	
				// Sprite renderer
				Renderer2D.BeginScene(*primaryCamera, primaryCameraTransform, .BackToFront);
	
				for (var (entity, transform, sprite) in _ecsWorld.Enumerate<TransformComponent, SpriterRendererComponent>())
				{
					Renderer2D.DrawSprite(transform.WorldTransform, sprite, entity.Index);
				}
	
				Renderer2D.EndScene();
	
				// Gamma correct composit target and draw it into viewport
				{
					RenderCommand.UnbindRenderTargets();
					RenderCommand.SetRenderTargetGroup(finalTarget, false);
					RenderCommand.BindRenderTargets();
	
					_gammaCorrectEffect.SetTexture("Texture", _compositeTarget, 0);
					// TODO: iiihhh
					_gammaCorrectEffect.Bind(Application.Get().Window.Context);
	
					FullscreenQuad.Draw();
				}
			}

			finalTarget.ReleaseRef();*/





			/*
			Debug.Profiler.ProfileRendererFunction!();
			
			TransformSystem.Update(_ecsWorld);

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

			Camera* primaryCamera = null;
			Matrix primaryCameraTransform = default;
			RenderTargetGroup renderTarget = null;

			for (var (entity, transform, camera) in _ecsWorld.Enumerate<TransformComponent, CameraComponent>())
			{
				if (camera.Primary && camera.RenderTarget != null)
				{
					primaryCamera = &camera.Camera;
					primaryCameraTransform = transform.WorldTransform;
					renderTarget = camera.RenderTarget..AddRef();
				}
			}
			
			if (primaryCamera != null)
			{
				// 3D render
				Renderer.BeginScene(*primaryCamera, primaryCameraTransform, renderTarget, finalTarget);

				for (var (entity, transform, mesh, meshRenderer) in _ecsWorld.Enumerate<TransformComponent, MeshComponent, MeshRendererComponent>())
				{
					Renderer.Submit(mesh.Mesh, meshRenderer.Material, transform.WorldTransform);
				}

				for (var (entity, transform, light) in _ecsWorld.Enumerate<TransformComponent, LightComponent>())
				{
					Renderer.Submit(light.SceneLight, transform.WorldTransform);
				}

				Renderer.EndScene();

				// Sprite renderer
				Renderer2D.BeginScene(*primaryCamera, primaryCameraTransform);
	
				for (var (entity, transform, sprite) in _ecsWorld.Enumerate<TransformComponent, SpriterRendererComponent>())
				{
					Renderer2D.DrawQuad(transform.WorldTransform, sprite.Sprite, sprite.Color);
				}
	
				Renderer2D.EndScene();

				renderTarget?.ReleaseRef();
			}
			*/
		}

		public void UpdateEditor(GameTime gameTime, EditorCamera camera, RenderTargetGroup viewportTarget, delegate void() DebugDraw3D, delegate void() DrawDebug2D)
		{
			Debug.Profiler.ProfileRendererFunction!();

			viewportTarget.AddRef();

			TransformSystem.Update(_ecsWorld);

			// 3D render
			Renderer.BeginScene(camera, _compositeTarget);

			for (var (entity, transform, mesh, meshRenderer) in _ecsWorld.Enumerate<TransformComponent, MeshComponent, MeshRendererComponent>())
			{
				if (mesh.Mesh == .Invalid || meshRenderer.Material == .Invalid)
					continue;

				Renderer.Submit(mesh.Mesh, meshRenderer.Material, entity, transform.WorldTransform);
			}

			for (var (entity, transform, light) in _ecsWorld.Enumerate<TransformComponent, LightComponent>())
			{
				Renderer.Submit(light.SceneLight, transform.WorldTransform);
			}

			DebugDraw3D();

			Renderer.EndScene();

			// TODO: alphablending (handle in Renderer2D)
			// TODO: 2D-Postprocessing requires rendering into separate target instead of directly into compositeTarget

			RenderCommand.SetRenderTargetGroup(_compositeTarget);
			RenderCommand.BindRenderTargets();

			// Sprite renderer
			Renderer2D.BeginScene(camera, .BackToFront);

			for (var (entity, transform, sprite) in _ecsWorld.Enumerate<TransformComponent, SpriterRendererComponent>())
			{
				Renderer2D.DrawSprite(transform.WorldTransform, sprite, entity.Index);
			}

			Renderer2D.EndScene();

			Renderer2D.BeginScene(camera, .BackToFront);

			DrawDebug2D();

			Renderer2D.EndScene();

			// Gamma correct composit target and draw it into viewport
			{
				RenderCommand.UnbindRenderTargets();
				RenderCommand.SetRenderTargetGroup(viewportTarget, false);
				RenderCommand.BindRenderTargets();
				
				Effect gammaEffect = Content.GetAsset<Effect>(_gammaCorrectEffect);

				gammaEffect.SetTexture("Texture", _compositeTarget, 0);
				// TODO: iiihhh
				gammaEffect.ApplyChanges();
				gammaEffect.Bind();
	
				FullscreenQuad.Draw();
			}

			viewportTarget.ReleaseRef();
		}

		/// Creates a new Entity with the given name.
		public Entity CreateEntity(String name = "", UUID id = default)
		{
			Entity entity = Entity(_ecsWorld.NewEntity(), this);
			entity.AddComponent<TransformComponent>();

			let nameComponent = entity.AddComponent<DebugNameComponent>();
			nameComponent.SetName(name.IsEmpty ? "Entity" : name);
			
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

		private uint32 ViewportWidth, ViewportHeight;

		/// Sets the size of the viewport into which the scene will be rendered.
		public void OnViewportResize(uint32 width, uint32 height)
		{
			ViewportWidth = width;
			ViewportHeight = height;

			for (var (entity, cameraComponent) in _ecsWorld.Enumerate<CameraComponent>())
			{
				if (!cameraComponent.Camera.FixedAspectRatio)
				{
					cameraComponent.Camera.SetViewportSize(width, height);
				}
			}

			_compositeTarget.Resize(ViewportWidth, ViewportHeight);
			_cameraTarget.Resize(ViewportWidth, ViewportHeight);
		}

		private void OnComponentAdded(Entity entity, Type componentType, void* component)
		{
			if (_onComponentAddedHandlers.TryGetValue(componentType, let handler))
			{
				handler(entity, componentType, component);
			}
		}
	}
}
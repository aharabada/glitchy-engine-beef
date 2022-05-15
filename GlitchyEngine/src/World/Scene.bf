using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;
using System.Collections;

namespace GlitchyEngine.World
{
	using internal ScriptableEntity;

	class Scene
	{
		internal EcsWorld _ecsWorld = new .() ~ delete _;
		
		private Dictionary<Type, function void(Entity entity, Type componentType, void* component)> _onComponentAddedHandlers = new .() ~ delete _;
		
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
			Entity entity = CreateEntity("Green Quad");
			entity.AddComponent<SpriterRendererComponent>(.(ColorRGBA(0.2f, 0.9f, 0.15f)));

			Entity entity2 = CreateEntity("Red Square");
			var v = entity2.AddComponent<SpriterRendererComponent>(.(ColorRGBA(0.95f, 0.1f, 0.3f)));
			v.Sprite = new Texture2D("Textures/rocket.dds");
			v.Sprite.SamplerState = SamplerStateManager.PointClamp;

			_onComponentAddedHandlers.Add(typeof(CameraComponent), (e, t, c) => {
				CameraComponent* cameraComponent = (.)c;

				cameraComponent.Camera.SetViewportSize(e.Scene.ViewportWidth, e.Scene.ViewportHeight);
			});
		}

		public ~this()
		{
		}

		public void Update(GameTime gameTime, RenderTarget2D finalTarget)
		{
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
			RenderTarget2D renderTarget = null;

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

				for (var (entity, transform, camera) in _ecsWorld.Enumerate<TransformComponent, LightComponent>())
				{
					Renderer.Submit(camera.SceneLight, transform.WorldTransform);
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
		}

		/// Creates a new Entity with the given name.
		public Entity CreateEntity(String name = "")
		{
			Entity entity = Entity(_ecsWorld.NewEntity(), this);
			entity.AddComponent<TransformComponent>();

			let nameComponent = entity.AddComponent<DebugNameComponent>();
			nameComponent.SetName(name.IsEmpty ? "Entity" : name);

			return entity;
		}

		/** Deletes the given entity.
		 * @param entity The entity to delete.
		 * @param destroyChildren If set to true all children of entity will be destroyed.
		*/
		public void DestroyEntity(Entity entity, bool destroyChildren = false)
		{
			if (destroyChildren)
			{
				for (Entity child in entity.EnumerateChildren)
				{
					DestroyEntity(child, true);
				}
			}
			
			_ecsWorld.RemoveEntity(entity.Handle);
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
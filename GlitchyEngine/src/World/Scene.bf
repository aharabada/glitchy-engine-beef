using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;

namespace GlitchyEngine.World
{
	using internal ScriptableEntity;

	class Scene
	{
		internal EcsWorld _ecsWorld = new .() ~ delete _;

		public this()
		{
			Entity entity = CreateEntity("Green Quad");
			entity.AddComponent<SpriterRendererComponent>(.(ColorRGBA(0.2f, 0.9f, 0.15f)));

			Entity entity2 = CreateEntity("Red Square");
			var v = entity2.AddComponent<SpriterRendererComponent>(.(ColorRGBA(0.95f, 0.1f, 0.3f)));
			v.Sprite = new Texture2D("Textures/rocket.png");
			v.Sprite.SamplerState = SamplerStateManager.PointClamp;

		}

		public ~this()
		{
		}

		public void Update(GameTime gameTime)
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

			for (var (entity, transform, camera) in _ecsWorld.Enumerate<TransformComponent, CameraComponent>())
			{
				if (camera.Primary)
				{
					primaryCamera = &camera.Camera;
					primaryCameraTransform = transform.WorldTransform;
				}
			}
			
			// Sprite renderer
			if (primaryCamera != null)
			{ 
				Renderer2D.BeginScene(*primaryCamera, primaryCameraTransform);
	
				for (var (entity, transform, sprite) in _ecsWorld.Enumerate<TransformComponent, SpriterRendererComponent>())
				{
					Renderer2D.DrawQuad(transform.WorldTransform, sprite.Sprite, sprite.Color);
				}
	
				Renderer2D.EndScene();
			}
		}

		public Entity CreateEntity(String name = "")
		{
			Entity entity = Entity(_ecsWorld.NewEntity(), this);
			entity.AddComponent<TransformComponent>();

			let nameComponent = entity.AddComponent<DebugNameComponent>();
			nameComponent.SetName(name.IsEmpty ? "Entity" : name);

			return entity;
		}

		public void DestroyEntity(Entity entity)
		{
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
				if (!cameraComponent.FixedAspectRatio)
				{
					cameraComponent.Camera.SetViewportSize(width, height);
				}
			}
		}
	}
}
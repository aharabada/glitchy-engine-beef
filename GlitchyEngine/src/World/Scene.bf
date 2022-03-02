using GlitchyEngine.Math;
using GlitchyEngine.Renderer;
using System;

namespace GlitchyEngine.World
{
	class Scene
	{
		internal EcsWorld _ecsWorld = new .() ~ delete _;

		public this()
		{
			Entity entity = CreateEntity();
			entity.AddComponent<SpriterRendererComponent>(.(ColorRGBA(0.2f, 0.9f, 0.15f)));
		}

		public ~this()
		{
		}

		public void Update(GameTime gameTime)
		{
			//TransformSystem.Update(_ecsWorld);

			Camera* primaryCamera = null;
			Matrix* primaryCameraTransform = null;

			for (var (entity, transform, camera) in _ecsWorld.Enumerate<SimpleTransformComponent, CameraComponent>())
			{
				if (camera.Primary)
				{
					primaryCamera = &camera.Camera;
					primaryCameraTransform = &transform.Transform;
				}
			}
			
			// Sprite renderer
			if (primaryCamera != null)
			{ 
				Renderer2D.BeginScene(*primaryCamera, *primaryCameraTransform);
	
				for (var (entity, transform, sprite) in _ecsWorld.Enumerate<SimpleTransformComponent, SpriterRendererComponent>())
				{
					Renderer2D.DrawQuad(transform.Transform, sprite.Color);
				}
	
				Renderer2D.EndScene();
			}
		}

		public Entity CreateEntity(String name = "")
		{
			Entity entity = Entity(_ecsWorld.NewEntity(), this);
			entity.AddComponent<SimpleTransformComponent>(.(.Identity));

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
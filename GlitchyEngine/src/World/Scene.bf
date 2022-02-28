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

			for (var (entity, transform, sprite) in _ecsWorld.Enumerate<SimpleTransformComponent, SpriterRendererComponent>())
			{
				Renderer2D.DrawQuad(transform.Transform, sprite.Color);
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
	}
}
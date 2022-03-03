using System;

using internal GlitchyEngine.World;

namespace GlitchyEngine.World
{
	public struct Entity
	{
		private EcsEntity _entity = .InvalidEntity;

		private Scene _scene = null;

		public EcsEntity Handle => _entity;

		public Scene Scene => _scene;

		public this()
		{
		}

		public this(EcsEntity entity, Scene scene)
		{
			_entity = entity;
			_scene = scene;
		}

		public bool IsValid => _entity.IsValid;

		public T* AddComponent<T>(T value = T()) where T: struct, new
		{
			Log.EngineLogger.AssertDebug(!HasComponent<T>(), scope $"Entity already has component.");

			return _scene._ecsWorld.AssignComponent<T>(_entity, value);
		}

		public T* GetComponent<T>() where T: struct, new
		{
			Log.EngineLogger.AssertDebug(HasComponent<T>(), "Entity doesn't have component!");

			return _scene._ecsWorld.GetComponent<T>(_entity);
		}
		
		public bool HasComponent<T>() where T: struct, new
		{
			return _scene._ecsWorld.HasComponent<T>(_entity);
		}
		
		public void RemoveComponent<T>() where T: struct, new
		{
			Log.EngineLogger.AssertDebug(HasComponent<T>(), "Entity doesn't have component!");

			_scene._ecsWorld.RemoveComponent<T>(_entity);
		}
	}
}

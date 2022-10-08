using System;
using System.Collections;

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

		public ChildEnumerator EnumerateChildren => .(this);

		public bool IsValid => _entity.IsValid && _scene != null;

		public Entity? Parent
		{
			get
			{
				var cmp = GetComponent<TransformComponent>();

				if (cmp.Parent == .InvalidEntity)
					return null;

				return .(cmp.Parent, _scene);
			}
			set
			{
				if (value == null)
				{
					var cmp = GetComponent<TransformComponent>();
					cmp.Parent = .InvalidEntity;
				}
				else
				{
					Entity parent = value.Value;

					if (parent.Scene != _scene)
					{
						Log.EngineLogger.AssertDebug(false);
						return;
					}

					var cmp = GetComponent<TransformComponent>();
					cmp.Parent = parent._entity;
				}
			}
		}

		public TransformComponent* Transform => GetComponent<TransformComponent>();

		public T* AddComponent<T>(T value = T()) where T: struct, new
		{
			Log.EngineLogger.AssertDebug(!HasComponent<T>(), scope $"Entity already has component.");

			T* component = _scene._ecsWorld.AssignComponent<T>(_entity, value);

			_scene.[Friend]OnComponentAdded(this, typeof(T), component);

			return component;
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

		public bool TryGetComponent<T>(out T* component) where T: struct, new
		{
			if (HasComponent<T>())
			{
				component = GetComponent<T>();
				return true;
			}

			component = null;
			return false;
		}
		
		public void RemoveComponent<T>() where T: struct, new
		{
			Log.EngineLogger.AssertDebug(HasComponent<T>(), "Entity doesn't have component!");

			_scene._ecsWorld.RemoveComponent<T>(_entity);
		}

		public struct ChildEnumerator : IEnumerator<Entity>, IDisposable
		{
			private WorldEnumerator<TransformComponent> _transformEnum;

			private EcsEntity _entity;
			private Entity _currentChild;

			public this(Entity entity)
			{
				_entity = entity.Handle;
				_transformEnum = entity.Scene._ecsWorld.Enumerate<TransformComponent>();
				_currentChild = .(.InvalidEntity, entity.Scene);
			}

			public Entity Current => _currentChild;

			public Result<Entity> GetNext() mut
			{
				while (true)
				{
					(EcsEntity entity, TransformComponent* transform) = Try!(_transformEnum.GetNext());

					if (transform.Parent == _entity)
					{
						_currentChild.[Friend]_entity = entity;
						return .Ok(_currentChild);
					}
				}
			}

			public void Dispose()
			{
				_transformEnum.Dispose();
			}
		}
	}
}

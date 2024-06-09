using System;
using System.Collections;
using GlitchyEngine.Math;

using internal GlitchyEngine.World;

namespace GlitchyEngine.World
{
	public class EcsWorld
	{
		const int MaxEntities = 16348;
		
		internal typealias BitmaskEntry = (EcsEntity ID, BitArray ComponentMask);
		internal List<BitmaskEntry> _entities = new .();

		List<uint32> _freeIndices = new List<uint32>() ~ delete _;

		typealias DisposeFunction = function void(void* component);

		internal typealias ComponentPoolEntry = (uint32 Id, IComponentPool Pool, DisposeFunction DisposeComponent);
		internal Dictionary<Type, ComponentPoolEntry> _componentPools = new .();

		/// A list containing all pools whose components need to be disposed before removal.
		List<Type> _disposingPools = new .() ~ delete _;
		
		public ~this()
		{
			for(var entry in _entities)
			{
				DisposeComponents(entry);

				delete entry.ComponentMask;
			}

			delete _entities;
			for(var entry in _componentPools)
			{
				delete entry.value.Pool;
			}

			delete _componentPools;
		}

		/**
		 * Registers a new Component.
		 */
		public void Register<T>() where T: struct, new
		{
			uint32 id = (uint32)_componentPools.Count;
			ComponentPool<T> componentPool = new ComponentPool<T>(MaxEntities);

			_componentPools.Add(typeof(T), (id, componentPool, null));
		}
		
		/**
		 * Registers a new Component.
		 */
		public void Register<T>() where T: struct, new, IDisposableComponent
		{
			uint32 id = (uint32)_componentPools.Count;
			ComponentPool<T> componentPool = new ComponentPool<T>(MaxEntities);

			DisposeFunction disposeFunction = => DisposeComponent<T>;

			_componentPools.Add(typeof(T), (id, componentPool, disposeFunction));

			// Add to list of components that need disposing
			_disposingPools.Add(typeof(T));
		}

		/// Enables us to bind a function pointer to the components dispose function
		private static void DisposeComponent<T>(void* component) where T : IDisposableComponent
		{
			T* myComponent = (T*)component;
			(*myComponent).Dispose();
		}

		/** @brief Returns the component pool for the given component type.
		 * @param TComponent The type of the component whose component pool will be returned.
		 * @returns A reference to the component pool.
		 */
		[Inline]
		internal ref ComponentPoolEntry GetComponentPool<TComponent>()
		{
			return ref _componentPools[typeof(TComponent)];
		}

		/**
		 * Creates a new Entity and returns its ID.
		 */
		public EcsEntity NewEntity()
		{
			EcsEntity entity;

			// Reuse freed entity slot
			if(_freeIndices.Count > 0)
			{
				uint32 index = _freeIndices.PopBack();

				entity = EcsEntity.CreateEntityID(index, _entities[index].ID.Version);

				_entities[index].ID = entity;
			}
			// Create new entity slot
			else
			{
				entity = EcsEntity.CreateEntityID((.)_entities.Count, 0);
				_entities.Add((entity, new BitArray(_componentPools.Count)));
			}

			return entity;
		}

		/**
		 * Removes the specified Entity from the World.
		 */
		public void RemoveEntity(EcsEntity entity)
		{
			Log.EngineLogger.AssertDebug(IsValid(entity));

			var listEntity = ref _entities[entity.Index];
			if(entity != listEntity.ID)
				return;

			DisposeComponents(listEntity);

			// Invalidate entry and increment version
			listEntity.ID = EcsEntity.CreateEntityID(EcsEntity.InvalidEntity.Index, entity.Version + 1);

			_entities[entity.Index].ComponentMask.Clear();
			_freeIndices.Add(entity.Index);
		}

		/// Disposes all components of the given entity.
		private void DisposeComponents(BitmaskEntry listEntity)
		{
			var componentMask = listEntity.ComponentMask;

			for(let poolType in _disposingPools)
			{
				var pool = _componentPools[poolType];

				// Check if the entity has this component type
				if(componentMask[pool.Id])
				{
					// Get pointer to component
					void* component = pool.Pool.Get(listEntity.ID.Index);
					// Dispose component
					pool.DisposeComponent(component);
				}
			}
		}

		/// Returns whether the given entity is valid or not.
		public bool IsValid(EcsEntity entity)
		{
			if(entity.Index > _entities.Count)
				return false;
			
			var listEntity = ref _entities[entity.Index];
			
			return entity == listEntity.ID;
		}

		/// Returns the entity with the same ID and the current version. Or null, if no such entity exists.
		public Result<EcsEntity> GetCurrentVersion(EcsEntity entity)
		{
			if(entity.Index > _entities.Count)
				return .Err;
			
			var listEntity = ref _entities[entity.Index];
			
			return listEntity.ID;
		}

		/**
		 * Assigns a component of type T to the specified entity and returns it.
		 */
		public T* AssignComponent<T>(EcsEntity entity, T value = T()) where T : struct, new
		{
			Log.EngineLogger.AssertDebug(IsValid(entity));

			if(entity.Index > _entities.Count)
				return null;

			var listEntity = ref _entities[entity.Index];

			if(entity != listEntity.ID)
				return null;

			ComponentPoolEntry entry;
			if(!_componentPools.TryGetValue(typeof(T), out entry))
			{
				Register<T>();

				entry = _componentPools[typeof(T)];

				//Log.EngineLogger.AssertDebug(false, scope $"Tried to assign unregistered component type {typeof(T)}");
				//return null;
			}
			
			// TODO: is it a problem to assign a component again?
			//if(listEntity.ComponentMask[entry.Id])
			//	return null;
			
			listEntity.ComponentMask[entry.Id] = true;

			T* component = (T*)entry.Pool.Get(entity.Index);

			*component = value;

			return component;
		}

		/**
		 * Removes a component of type T from the specified entity.
		 */
		public void RemoveComponent<T>(EcsEntity entity) where T : struct, new
		{
			Log.EngineLogger.AssertDebug(IsValid(entity));

			if(entity.Index > _entities.Count)
				return;

			var listEntity = ref _entities[entity.Index];
			if(entity != listEntity.ID)
				return;
			
			ComponentPoolEntry entry;
			if(!_componentPools.TryGetValue(typeof(T), out entry))
				return;
			
			// TODO: maybe assert?
			if(!listEntity.ComponentMask[entry.Id])
				return;
			
			listEntity.ComponentMask[entry.Id] = false;
		}

		public void RemoveComponent<T>(EcsEntity entity) where T : struct, new, IDisposableComponent
		{
			Log.EngineLogger.AssertDebug(IsValid(entity));

			if(entity.Index > _entities.Count)
				return;

			var listEntity = ref _entities[entity.Index];
			if(entity != listEntity.ID)
				return;
			
			ComponentPoolEntry entry;
			if(!_componentPools.TryGetValue(typeof(T), out entry))
				return;
			
			// TODO: maybe assert?
			if(!listEntity.ComponentMask[entry.Id])
				return;
			
			listEntity.ComponentMask[entry.Id] = false;

			// Get component and call dispose
			DisposeComponent<T>(entry.Pool.Get(entity.Index));
		}

		/// Returns whether or not the given entity has the specified component.
		public bool HasComponent<T>(EcsEntity entity) where T : struct, new
		{
			Log.EngineLogger.AssertDebug(IsValid(entity));

			var listEntity = ref _entities[entity.Index];
			if(entity != listEntity.ID)
				return false;
			
			ComponentPoolEntry entry;
			if(!_componentPools.TryGetValue(typeof(T), out entry))
				return false;

			return listEntity.ComponentMask[entry.Id];
		}

		public T* GetComponent<T>(EcsEntity entity) where T : struct, new
		{
			Log.EngineLogger.AssertDebug(IsValid(entity));

			var listEntity = ref _entities[entity.Index];
			if(entity != listEntity.ID)
				return null;
			
			ComponentPoolEntry entry;
			if(!_componentPools.TryGetValue(typeof(T), out entry))
				return null;

			// TODO: maybe assert?
			if(!listEntity.ComponentMask[entry.Id])
				return null;

			return (.)entry.Pool.Get(entity.Index);
		}

		public WorldEnumerator Enumerate(params Type[] componentTypes)
		{
			return WorldEnumerator(this, componentTypes);
		}

		public WorldEnumerator<TComponent> Enumerate<TComponent>() where TComponent : struct
		{
			return WorldEnumerator<TComponent>(this);
		}

		public WorldEnumerator<TComponent0, TComponent1> Enumerate<TComponent0, TComponent1>() where TComponent0 : struct
			where TComponent1 : struct
		{
			return WorldEnumerator<TComponent0, TComponent1>(this);
		}
		
		public WorldEnumerator<TComponent0, TComponent1, TComponent2> Enumerate<TComponent0, TComponent1, TComponent2>()
			where TComponent0 : struct where TComponent1 : struct where TComponent2 : struct
		{
			return WorldEnumerator<TComponent0, TComponent1, TComponent2>(this);
		}

		public WorldEnumerator<TComponent0, TComponent1, TComponent2, TComponent3> Enumerate<TComponent0, TComponent1, TComponent2, TComponent3>()
			where TComponent0 : struct where TComponent1 : struct where TComponent2 : struct where TComponent3 : struct
		{
			return WorldEnumerator<TComponent0, TComponent1, TComponent2, TComponent3>(this);
		}

		public static void Test()
		{
			EcsWorld world = new .();

			world.Register<TransformComponent>();

			EcsEntity entity = world.NewEntity();

			TransformComponent* myComp = world.AssignComponent<TransformComponent>(entity);
			myComp.LocalTransform = Matrix.Identity;

			#unwarn
			TransformComponent gotComp = *world.GetComponent<TransformComponent>(entity);

			world.RemoveComponent<TransformComponent>(entity);

			EcsEntity entity2 = world.NewEntity();
			world.AssignComponent<TransformComponent>(entity2);

			world.RemoveEntity(entity);

			entity = world.NewEntity();

			world.RemoveEntity(entity);
			world.RemoveComponent<TransformComponent>(entity);

			entity = world.NewEntity();

			for(let forenty in world.Enumerate(typeof(TransformComponent)))
			{

			}

			delete world;
		}

		/// A component to test automatic disposing of components.
		private struct TestDisposingComponent : IDisposableComponent
		{
			public bool IsDisposed;

			public void Dispose() mut
			{
				IsDisposed = true;
			}
		}

		/// Tets if disposing of components works correctly.
		[Test]
		public static void TestDisposing()
		{
			EcsWorld world = scope EcsWorld();
			world.Register<TestDisposingComponent>();

			// Test dispose on component removal
			{
				// Create entity with disposable component.
				EcsEntity entity = world.NewEntity();
				var component = world.AssignComponent<TestDisposingComponent>(entity);
				component.IsDisposed = false;
	
				world.RemoveComponent<TestDisposingComponent>(entity);

				Test.Assert(component.IsDisposed == true, "The component was not disposed when the component was removed!");
			}
			
			// Test dispose on entity removal
			{
				// Create entity with disposable component.
				EcsEntity entity = world.NewEntity();
				var component = world.AssignComponent<TestDisposingComponent>(entity);
				component.IsDisposed = false;
	
				world.RemoveEntity(entity);
				
				Test.Assert(component.IsDisposed == true, "The component was not disposed when the entity was removed!");
			}
		}
	}
}

using System;
using System.Collections;
using GlitchyEngine.Math;

using internal GlitchyEngine.World;

namespace GlitchyEngine.World
{
	public class EcsWorld
	{
		const int MaxEntities = 1024;
		
		typealias BitmaskEntry = (Entity ID, BitArray ComponentMask);
		List<BitmaskEntry> _entities = new .();

		List<uint32> _freeIndices = new List<uint32>() ~ delete _;

		typealias DisposeFunction = function void(void* component);

		typealias ComponentPoolEntry = (uint32 Id, ComponentPool Pool, DisposeFunction DisposeFunction);
		Dictionary<Type, ComponentPoolEntry> _componentPools = new .();

		/// A list containing all pools whose components need to be disposed before removal.
		List<ComponentPoolEntry*> _disposingPools = new .() ~ delete _;
		
		public ~this()
		{
			for(var entry in _componentPools)
			{
				delete entry.value.Pool;
			}

			delete _componentPools;

			for(var entry in _entities)
			{
				delete entry.ComponentMask;
			}

			delete _entities;
		}
		
		/**
		 * Registers a new Component.
		 */
		public void Register<T>() where T: struct
		{
			uint32 id = (uint32)_componentPools.Count;
			ComponentPool componentPool = new ComponentPool(sizeof(T), MaxEntities);

			_componentPools.Add(typeof(T), (id, componentPool, null));
		}
		
		/**
		 * Registers a new Component.
		 */
		public void Register<T>() where T: struct, IDisposableComponent
		{
			uint32 id = (uint32)_componentPools.Count;
			ComponentPool componentPool = new ComponentPool(sizeof(T), MaxEntities);
			DisposeFunction disposeFunction = => T.DisposeComponent;

			_componentPools.Add(typeof(T), (id, componentPool, disposeFunction));

			// We have to get the component from the dictionary so we get the reference
			var poolInDictionary = ref _componentPools[typeof(T)];
			// Add to list of components that need disposing
			_disposingPools.Add(&poolInDictionary);
		}

		/**
		 * Creates a new Entity and returns its ID.
		 */
		public Entity NewEntity()
		{
			Entity entity;

			// Reuse freed entity slot
			if(_freeIndices.Count > 0)
			{
				uint32 index = _freeIndices.PopBack();

				entity = Entity.CreateEntityID(index, _entities[index].ID.Version);

				_entities[index].ID = entity;
			}
			// Create new entity slot
			else
			{
				entity = Entity.CreateEntityID((.)_entities.Count, 0);
				_entities.Add((entity, new BitArray(_componentPools.Count)));
			}

			return entity;
		}

		/**
		 * Removes the specified Entity from the World.
		 */
		public void RemoveEntity(Entity entity)
		{
			var listEntity = ref _entities[entity.Index];
			if(entity != listEntity.ID)
				return;

			DisposeComponents(listEntity);

			// Invalidate entry and increment version
			listEntity.ID = Entity.CreateEntityID(Entity.InvalidEntity.Index, entity.Version + 1);

			_entities[entity.Index].ComponentMask.Clear();
			_freeIndices.Add(entity.Index);
		}

		/// Disposes all components of the given entity.
		private void DisposeComponents(BitmaskEntry listEntity)
		{
			var componentMask = listEntity.ComponentMask;

			for(let poolEntry in _disposingPools)
			{
				// Check if the entity has this component type
				if(componentMask[poolEntry.Id])
				{
					// Get pointer to component
					void* component = poolEntry.Pool.Get(listEntity.ID.Index);
					// Dispose component
					poolEntry.DisposeFunction(component);
				}
			}
		}

		/**
		 * Assigns a component of type T to the specified entity and returns it.
		 */
		public T* AssignComponent<T>(Entity entity) where T : struct
		{
			if(entity.Index > _entities.Count)
				return null;

			var listEntity = ref _entities[entity.Index];

			if(entity != listEntity.ID)
				return null;

			ComponentPoolEntry entry;
			if(!_componentPools.TryGetValue(typeof(T), out entry))
			{
				Log.EngineLogger.Error($"Tried to assign unregistered component type {typeof(T)}");
				return null;
				//entry = ((uint32)_componentPools.Count, new ComponentPool(sizeof(T), MaxEntities));

				//_componentPools.Add(typeof(T), entry);
			}
			
			// TODO: maybe assert?
			if(listEntity.ComponentMask[entry.Id])
				return null;
			
			listEntity.ComponentMask[entry.Id] = true;
			
			return (.)entry.Pool.Get(entity.Index);
		}

		/**
		 * Removes a component of type T from the specified entity.
		 */
		public void RemoveComponent<T>(Entity entity) where T : struct
		{
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
		
		public void RemoveComponent<T>(Entity entity) where T : struct, IDisposableComponent
		{
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
			T.DisposeComponent(entry.Pool.Get(entity.Index));
		}

		public T* GetComponent<T>(Entity entity) where T : struct
		{
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

		public struct WorldEnumerator : IEnumerator<Entity>, IDisposable
		{
			private EcsWorld _world;
			private BitArray _bitMask;
			private BitmaskEntry* _currentEntry;
			private BitmaskEntry* _endEntry;

			public this(EcsWorld world, Type[] componentTypes)
			{
				_world = world;
				_currentEntry = _world._entities.Ptr;
				_endEntry = _world._entities.Ptr + _world._entities.Count;

				_bitMask = new BitArray(_world._componentPools.Count);
				for(var type in componentTypes)
				{
					Log.EngineLogger.AssertDebug(type.IsStruct, "Components can only be structs.");

					var result = _world._componentPools.GetValue(type);

					if(result case .Ok(let entry))
					{
						_bitMask[entry.Id] = true;
					}
					else
					{
						Log.EngineLogger.AssertDebug(false, "Queried component is not registered for this world. This is invalid because the query would never return any results.");
					}
				}
			}

			public Result<Entity> GetNext() mut
			{
				while(_currentEntry < _endEntry)
				{
					BitmaskEntry* entry = _currentEntry++;
					// Check whether or not mask matches
					if(entry.ComponentMask.MaskMatch(_bitMask))
						return entry.ID;
				}

				return .Err;
			}

			public void Dispose()
			{
				delete _bitMask;
			}
		}

		public static void Test()
		{
			EcsWorld world = new .();

			world.Register<TransformComponent>();

			Entity entity = world.NewEntity();

			TransformComponent* myComp = world.AssignComponent<TransformComponent>(entity);
			myComp.LocalTransform = Matrix.Identity;

			#unwarn
			TransformComponent gotComp = *world.GetComponent<TransformComponent>(entity);

			world.RemoveComponent<TransformComponent>(entity);

			Entity entity2 = world.NewEntity();
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

			public static void DisposeComponent(void* component)
			{
				Self* testComponent = (Self*)component;
				testComponent.IsDisposed = true;
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
				Entity entity = world.NewEntity();
				var component = world.AssignComponent<TestDisposingComponent>(entity);
				component.IsDisposed = false;
	
				world.RemoveComponent<TestDisposingComponent>(entity);

				Test.Assert(component.IsDisposed == true, "The component was not disposed when the component was removed!");
			}
			
			// Test dispose on entity removal
			{
				// Create entity with disposable component.
				Entity entity = world.NewEntity();
				var component = world.AssignComponent<TestDisposingComponent>(entity);
				component.IsDisposed = false;
	
				world.RemoveEntity(entity);
				
				Test.Assert(component.IsDisposed == true, "The component was not disposed when the entity was removed!");
			}
		}
	}
}

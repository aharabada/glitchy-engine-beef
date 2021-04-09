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

		typealias ComponentPoolEntry = (uint32 Id, ComponentPool Pool);
		Dictionary<Type, ComponentPoolEntry> _componentPools = new .();
		
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
			_componentPools.Add(typeof(T), ((uint32)_componentPools.Count, new ComponentPool(sizeof(T), MaxEntities)));
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

			listEntity.ID = Entity.CreateEntityID(Entity.InvalidEntity.Index, entity.Version + 1);
			
			_entities[entity.Index].ComponentMask.Clear();
			_freeIndices.Add(entity.Index);

			// TODO: add "destructor" for components
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
				entry = ((uint32)_componentPools.Count, new ComponentPool(sizeof(T), MaxEntities));

				_componentPools.Add(typeof(T), entry);
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
			myComp.Transform = Matrix.Identity;

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
	}
}

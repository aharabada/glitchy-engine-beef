using System.Collections;
using System;
using GlitchyEngine.Math;

using internal GlitchyEngine.World;

namespace GlitchyEngine.World
{
	public struct WorldEnumerator : IEnumerator<EcsEntity>, IDisposable
	{
		internal EcsWorld _world;
		internal BitArray _bitMask;
		internal EcsWorld.BitmaskEntry* _currentEntry;
		internal EcsWorld.BitmaskEntry* _endEntry;

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
					//Log.EngineLogger.AssertDebug(false, "Queried component is not registered for this world. This is invalid because the query would never return any results.");
				}
			}
		}

		public Result<EcsEntity> GetNext() mut
		{
			while(_currentEntry < _endEntry)
			{
				EcsWorld.BitmaskEntry* entry = _currentEntry++;

				// Skip deleted entities
				if(entry.ID.Index == EcsEntity.InvalidEntity.Index)
					continue;

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

	public struct WorldEnumerator<TComponent> : WorldEnumerator, IEnumerator<(EcsEntity Entity, TComponent* Component)> where TComponent : struct
	{
		internal EcsWorld.ComponentPoolEntry* _componentPool;

		public this(EcsWorld world) : base(world, scope Type[](typeof(TComponent)))
		{
			_componentPool = &world.GetComponentPool<TComponent>();
		}

		public new Result<(EcsEntity Entity, TComponent* Component)> GetNext() mut
		{
			Result<EcsEntity> entity = base.GetNext();

			if(entity case .Err)
				return .Err;
			
			TComponent* component = (.)_componentPool.Pool.Get(entity.Value.Index);

			return .Ok((entity.Value, component));
		}
	}

	public struct WorldEnumerator<TComponent0, TComponent1> : WorldEnumerator,
		IEnumerator<(EcsEntity Entity, TComponent0* Component0, TComponent1* Component1)>
		where TComponent0 : struct where TComponent1 : struct
	{
		internal EcsWorld.ComponentPoolEntry* _componentPool0;
		internal EcsWorld.ComponentPoolEntry* _componentPool1;

		public this(EcsWorld world) : base(world, scope Type[](typeof(TComponent0), typeof(TComponent1)))
		{
			_componentPool0 = &world.GetComponentPool<TComponent0>();
			_componentPool1 = &world.GetComponentPool<TComponent1>();
		}

		public new Result<(EcsEntity Entity, TComponent0* Component0, TComponent1* Component1)> GetNext() mut
		{
			Result<EcsEntity> entity = base.GetNext();

			if(entity case .Err)
				return .Err;
			
			TComponent0* component0 = (.)_componentPool0.Pool.Get(entity.Value.Index);
			TComponent1* component1 = (.)_componentPool1.Pool.Get(entity.Value.Index);

			return .Ok((entity.Value, component0, component1));
		}
	}

	public struct WorldEnumerator<TComponent0, TComponent1, TComponent2> : WorldEnumerator,
		IEnumerator<(EcsEntity Entity, TComponent0* Component0, TComponent1* Component1, TComponent2* Component2)>
		where TComponent0 : struct where TComponent1 : struct where TComponent2 : struct
	{
		internal EcsWorld.ComponentPoolEntry* _componentPool0;
		internal EcsWorld.ComponentPoolEntry* _componentPool1;
		internal EcsWorld.ComponentPoolEntry* _componentPool2;

		public this(EcsWorld world) : base(world, scope Type[](typeof(TComponent0), typeof(TComponent1), typeof(TComponent2)))
		{
			_componentPool0 = &world.GetComponentPool<TComponent0>();
			_componentPool1 = &world.GetComponentPool<TComponent1>();
			_componentPool2 = &world.GetComponentPool<TComponent2>();
		}

		public new Result<(EcsEntity Entity, TComponent0* Component0, TComponent1* Component1, TComponent2* Component2)> GetNext() mut
		{
			Result<EcsEntity> entity = base.GetNext();

			if(entity case .Err)
				return .Err;
			
			TComponent0* component0 = (.)_componentPool0.Pool.Get(entity.Value.Index);
			TComponent1* component1 = (.)_componentPool1.Pool.Get(entity.Value.Index);
			TComponent2* component2 = (.)_componentPool2.Pool.Get(entity.Value.Index);

			return .Ok((entity.Value, component0, component1, component2));
		}
	}

	public struct WorldEnumerator<TComponent0, TComponent1, TComponent2, TComponent3> : WorldEnumerator,
		IEnumerator<(EcsEntity Entity, TComponent0* Component0, TComponent1* Component1, TComponent2* Component2, TComponent3* Component3)>
		where TComponent0 : struct where TComponent1 : struct where TComponent2 : struct where TComponent3 : struct
	{
		internal EcsWorld.ComponentPoolEntry* _componentPool0;
		internal EcsWorld.ComponentPoolEntry* _componentPool1;
		internal EcsWorld.ComponentPoolEntry* _componentPool2;
		internal EcsWorld.ComponentPoolEntry* _componentPool3;

		public this(EcsWorld world) : base(world, scope Type[](typeof(TComponent0), typeof(TComponent1), typeof(TComponent2), typeof(TComponent3)))
		{
			_componentPool0 = &world.GetComponentPool<TComponent0>();
			_componentPool1 = &world.GetComponentPool<TComponent1>();
			_componentPool2 = &world.GetComponentPool<TComponent2>();
			_componentPool3 = &world.GetComponentPool<TComponent3>();
		}

		public new Result<(EcsEntity Entity, TComponent0* Component0, TComponent1* Component1, TComponent2* Component2, TComponent3* Component3)> GetNext() mut
		{
			Result<EcsEntity> entity = base.GetNext();

			if(entity case .Err)
				return .Err;
			
			TComponent0* component0 = (.)_componentPool0.Pool.Get(entity.Value.Index);
			TComponent1* component1 = (.)_componentPool1.Pool.Get(entity.Value.Index);
			TComponent2* component2 = (.)_componentPool2.Pool.Get(entity.Value.Index);
			TComponent3* component3 = (.)_componentPool3.Pool.Get(entity.Value.Index);

			return .Ok((entity.Value, component0, component1, component2, component3));
		}
	}
}

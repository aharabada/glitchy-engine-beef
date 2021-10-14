using System;

namespace GlitchyEngine.World
{
	public interface IComponentPool
	{
		public void* Get(int index);
	}

	public class ComponentPool<T> : IComponentPool
	{
		int PoolSize => sizeof(T) * _data.Count;
		T[] _data ~ delete _;

		public this(int capacity)
		{
			_data = new T[capacity];
		}

		[Inline]
		public void* Get(int index)
		{
			Log.EngineLogger.AssertDebug(index >= 0 && index < _data.Count);

			return &_data[index];
		}
	}
}

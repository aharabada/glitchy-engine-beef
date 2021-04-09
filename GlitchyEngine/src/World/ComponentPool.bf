using System;

namespace GlitchyEngine.World
{
	public class ComponentPool
	{
		int _objectSize;
		int _capacity;

		int PoolSize => _objectSize * _capacity;

		uint8* _rawData ~ delete _;

		public this(int objectSize, int capacity)
		{
			_objectSize = objectSize;
			_capacity = capacity;

			_rawData = new uint8[_capacity * _objectSize]*;
		}

		[Inline]
		public void* Get(int index)
		{
			Log.EngineLogger.AssertDebug(index >= 0 && index < _capacity);

			return _rawData + index * _objectSize;
		}
	}
}

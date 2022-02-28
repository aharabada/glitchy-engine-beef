using System;

namespace GlitchyEngine.Math
{
	public class BitArray
	{
		const int BitsPerInt = sizeof(uint) * 8;

		private uint* _bits ~ Free(_);
		private int _intCount;
		private int _capacity;

		public int Capacity
		{
			get => _capacity;
			set => EnsureCapacity(value);
		}

		public this(int initialCapacity = sizeof(uint))
		{
			var initialCapacity;

			if (initialCapacity < sizeof(uint))
				initialCapacity = sizeof(uint);

			EnsureCapacity(initialCapacity);
		}

		[Inline]
		static int IntCount(int bits)
		{
			int count = bits / BitsPerInt;

			if(bits % BitsPerInt > 0)
				count++;

			return count;
		}
		
		[LinkName("free")]
		static extern void Free(void* memoryBlock);

		[LinkName("realloc")]
		static extern void* Realloc(void* memoryBlock, int size);

		private void EnsureCapacity(int requestedCapacity)
		{
			if(requestedCapacity <= _capacity)
				return;

			int newIntCount = IntCount(requestedCapacity);

			if(_intCount >= newIntCount)
				return;
			
			int oldIntCount = _intCount;
			_intCount = newIntCount;
			_capacity = _intCount * BitsPerInt;

			_bits = (.)Realloc(_bits, _intCount * sizeof(uint));

			// Set new bits to 0
			for(int i = oldIntCount; i < _intCount; i++)
			{
				_bits[i] = 0;
			}
		}

		public bool this[int index]
		{
			get
			{
				Log.EngineLogger.AssertDebug(index >= 0);

				if(index > _capacity)
					return false;

				int arrayIndex = index / _capacity;
				int bitIndex = index % _capacity;

				return ((_bits[arrayIndex] >> bitIndex) & 1) == 1;
			}

			set
			{
				Log.EngineLogger.AssertDebug(index >= 0);

				if(index > _capacity)
					EnsureCapacity(index);

				int arrayIndex = index / _capacity;
				int bitIndex = index % _capacity;

				if(value)
				{
					_bits[arrayIndex] |= (1 << bitIndex);
				}
				else
				{
					// create a mask that is all 1 except for the bit at the specified index
					uint mask = uint.MaxValue;
					mask ^= (1 << bitIndex);

					_bits[arrayIndex] &= mask;
				}
			}
		}

		/**
		 * Sets all bits to given value.
		 */
		public void Clear(bool value = false)
		{
			if(value)
			{
				for(int i < _intCount)
				{
					_bits[i] = (uint)-1;
				}
			}
			else
			{
				for(int i < _intCount)
				{
					_bits[i] = 0;
				}
			}
		}

		/**
		 * Returns whether or not this bitarray is 1 for every 1 in mask.
		 * i.e. mask == (this & mask)
		*/
		public bool MaskMatch(BitArray mask)
		{
			// The number of ints we can compare binary
			int intCompares = Math.Min(mask._intCount, _intCount);
			for(int i < intCompares)
			{
				if(mask._bits[i] != (_bits[i] & mask._bits[i]))
					return false;
			}

			// if mask has more integers than "this", these integers must be 0
			for(int i = _intCount; i < mask._intCount; i++)
			{
				if(mask._bits[i] > 0)
					return false;
			}

			return true;
		}
	}
}

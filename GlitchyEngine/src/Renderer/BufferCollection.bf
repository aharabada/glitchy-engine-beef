using System;
using System.Collections;
using GlitchyEngine.Core;

namespace GlitchyEngine.Renderer
{
	public class BufferCollection : RefCounter, IEnumerable<(String Name, Buffer Buffer)>
	{
		public static extern int MaxBufferSlotCount { get; }

		public typealias BufferEntry = (String Name, Buffer Buffer);

		BufferEntry[] _buffers ~ DeleteBufferEntries!(_);

		Dictionary<StringView, BufferEntry*> _strToBuf ~ delete _;

		[AllowAppend]
		public this()
		{
			Debug.Profiler.ProfileResourceFunction!();

			// Todo: append allocate as soon as it's fixed
			let buffers = new BufferEntry[MaxBufferSlotCount];
			let strToBuf = new Dictionary<StringView, BufferEntry*>();

			_buffers = buffers;
			_strToBuf = strToBuf;
		}

		public ~this()
		{
			Debug.Profiler.ProfileResourceFunction!();
		}
		
		mixin DeleteBufferEntries(BufferEntry[] entries)
		{
			if(entries == null)
				return;

			for(let entry in entries)
			{
				delete entry.Name;
				entry.Buffer?.ReleaseRef();
			}

			delete entries;
		}

		public Buffer this[int slot] => _buffers[slot].Buffer;
		public Buffer this[String name] => _strToBuf[name].Buffer;
		
		public Buffer TryGetBuffer(String name)
		{
			return TryGetBufferEntry(name)?.Buffer;
		}
		
		public Buffer TryGetBuffer(int slot)
		{
			return TryGetBufferEntry(slot)?.Buffer;
		}

		public BufferEntry* TryGetBufferEntry(String name)
		{
			if(_strToBuf.TryGetValue(name, let buffer))
			{
				return buffer;
			}

			return null;
		}

		public BufferEntry* TryGetBufferEntry(int slot)
		{
			if (slot < 0 || slot >= _buffers.Count)
				return null;

			return &_buffers[slot];
		}

		/**
		 * Replaces the buffer with the given index.
		 * @param idx The index (shader buffer register) of the buffer to replace.
		 * @param buffer The new buffer.
		 * @returns True, if the buffer was replaced successfully; false, otherwise.
		 */
		public bool TryReplaceBuffer(int slot, Buffer buffer)
		{
			BufferEntry* bufferEntry = TryGetBufferEntry(slot);
			if(bufferEntry != null)
			{
				SetReference!(bufferEntry.Buffer, buffer);

				return true;
			}
			else
			{
				return false;
			}
		}

		/**
		 * Replaces the buffer with the given name.
		 * @param name The name of the buffer to replace.
		 * @param buffer The new buffer.
		 * @returns True, if the buffer was replaced successfully; false, otherwise.
		 */
		public bool TryReplaceBuffer(String name, Buffer buffer)
		{
			if(_strToBuf.TryGetValue(name, let bufferEntry))
			{
				Log.EngineLogger.AssertDebug(name == bufferEntry.Name);

				SetReference!(bufferEntry.Buffer, buffer);

				return true;
			}
			else
			{
				return false;
			}
		}

		public void Add(int slot, StringView name, Buffer buffer)
		{
			ref BufferEntry bufferEntry = ref _buffers[slot];

			SetReference!(bufferEntry.Buffer, buffer);
			String.NewOrSet!(bufferEntry.Name, name);

			_strToBuf.Add(bufferEntry.Name, &bufferEntry);
		}

		/**
		 * Returns the index of the given Buffer in the _buffer-List.
		 * @param The buffer to find the index of.
		 * @returns The index of the buffer, or null if it isn't in this collection.
		 */
		int GetIndexOfBuffer(Buffer buffer)
		{
			Debug.Profiler.ProfileResourceFunction!();

			for(int i < _buffers.Count)
			{
				// Only check for reference equality.
				if(_buffers[i].Buffer === buffer)
				{
					return i;
				}
			}

			return -1;
		}

		/**
		 * Returns the index of the given Buffer in the _buffer-List.
		 * @param The buffer to find the index of.
		 * @returns The name of the buffer, or null if it isn't in this collection.
		 */
		String GetNameOfBuffer(Buffer buffer)
		{
			Debug.Profiler.ProfileResourceFunction!();

			for(int i < _buffers.Count)
			{
				// Only check for reference equality.
				if(_buffers[i].Buffer === buffer)
				{
					return _buffers[i].Name;
				}
			}

			return null;
		}

		public Span<BufferEntry>.Enumerator GetEnumerator()
		{
			return _buffers.GetEnumerator();
		}
	}
}

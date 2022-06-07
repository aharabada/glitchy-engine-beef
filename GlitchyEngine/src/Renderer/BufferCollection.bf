using System;
using System.Collections;
using GlitchyEngine.Core;

namespace GlitchyEngine.Renderer
{
	public class BufferCollection : RefCounter, IEnumerable<(String Name, int Index, Buffer Buffer)>
	{
		public typealias BufferEntry = (String Name, int Index, Buffer Buffer);

		List<BufferEntry> _buffers ~ DeleteBufferEntries!(_);

		Dictionary<String, BufferEntry*> _strToBuf ~ delete _; //delete:append _;
		Dictionary<int, BufferEntry*> _idxToBuf ~ delete _; //delete:append _;

		[AllowAppend]
		public this()
		{
			Debug.Profiler.ProfileResourceFunction!();

			// Todo: append allocate as soon as it's fixed
			let buffers = new List<BufferEntry>();
			let strToBuf = new Dictionary<String, BufferEntry*>();
			let idxToBuf = new Dictionary<int, BufferEntry*>();

			_buffers = buffers;
			_strToBuf = strToBuf;
			_idxToBuf = idxToBuf;
		}

		public ~this()
		{
			Debug.Profiler.ProfileResourceFunction!();
		}
		
		mixin DeleteBufferEntries(List<BufferEntry> entries)
		{
			if(entries == null)
				return;

			for(let entry in entries)
			{
				delete entry.Name;
				entry.Buffer.ReleaseRef();
			}

			delete entries;
		}

		public Buffer this[int idx] => _idxToBuf[idx].Buffer;
		public Buffer this[String name] => _strToBuf[name].Buffer;
		
		public Buffer TryGetBuffer(String name)
		{
			return TryGetBufferEntry(name)?.Buffer;
		}
		
		public Buffer TryGetBuffer(int index)
		{
			return TryGetBufferEntry(index)?.Buffer;
		}

		public BufferEntry* TryGetBufferEntry(String name)
		{
			Debug.Profiler.ProfileResourceFunction!();

			if(_strToBuf.TryGetValue(name, let buffer))
			{
				return buffer;
			}

			return null;
		}

		public BufferEntry* TryGetBufferEntry(int index)
		{
			Debug.Profiler.ProfileResourceFunction!();

			if(_idxToBuf.TryGetValue(index, let buffer))
			{
				return buffer;
			}

			return null;
		}

		/**
		 * Replaces the buffer with the given index.
		 * @param idx The index (shader buffer register) of the buffer to replace.
		 * @param buffer The new buffer.
		 * @returns True, if the buffer was replaced successfully; false, otherwise.
		 */
		public bool TryReplaceBuffer(int idx, Buffer buffer)
		{
			Debug.Profiler.ProfileResourceFunction!();

			if(_idxToBuf.TryGetValue(idx, let bufferEntry))
			{
				Log.EngineLogger.Assert(idx == bufferEntry.Index);

				bufferEntry.Buffer.ReleaseRef();

				buffer.AddRef();
				bufferEntry.Buffer = buffer;

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
			Debug.Profiler.ProfileResourceFunction!();

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

		public void Add(int index, String name, Buffer buffer)
		{
			Add((name, index, buffer));
		}

		public void Add(BufferEntry entry)
		{
			Debug.Profiler.ProfileResourceFunction!();

			BufferEntry copy = (new String(entry.Name), entry.Index, entry.Buffer..AddRef());

			_buffers.Add(copy);

			BufferEntry* copyRef = &_buffers.Back;

			_strToBuf.Add(copy.Name, copyRef);
			_idxToBuf.Add(copy.Index, copyRef);
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

		public List<BufferEntry>.Enumerator GetEnumerator()
		{
			return _buffers.GetEnumerator();
		}
	}
}

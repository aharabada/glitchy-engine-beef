using System;
using System.Collections;

namespace GlitchyEngine.Renderer
{
	public class BufferCollection
	{
		typealias BufferEntry = (String Name, int Index, Buffer Buffer);

		List<BufferEntry> _buffers ~ DeleteBufferEntries!(_);

		Dictionary<String, Buffer> _strToBuf ~ delete _; //delete:append _;
		Dictionary<int, Buffer> _idxToBuf ~ delete _; //delete:append _;

		[AllowAppend]
		public this()
		{
			// Todo: append allocate as soon as it's fixed
			let buffers = new List<BufferEntry>();
			let strToBuf = new Dictionary<String, Buffer>();
			let idxToBuf = new Dictionary<int, Buffer>();

			_buffers = buffers;
			_strToBuf = strToBuf;
			_idxToBuf = idxToBuf;
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

		public Buffer this[int idx] => _idxToBuf[idx];
		public Buffer this[String name] => _strToBuf[name];

		/**
		 * Replaces the buffer with the given index.
		 * @param idx The index (shader buffer register) of the buffer to replace.
		 * @param buffer The new buffer.
		 */
		public void ReplaceBuffer(int idx, Buffer buffer)
		{
			if(_idxToBuf.TryGetValue(idx, let oldBuffer))
			{
				int index = GetIndexOfBuffer(oldBuffer);

				ref BufferEntry bufferDesc = ref _buffers[index];

				Log.EngineLogger.Assert(idx == bufferDesc.Index);

				oldBuffer.ReleaseRef();

				buffer.AddRef();
				bufferDesc.Buffer = buffer;

				_strToBuf[bufferDesc.Name] = buffer;
				_idxToBuf[bufferDesc.Index] = buffer;
			}
			else
			{
				Log.EngineLogger.Assert(false, "No buffer at the given index.");
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
			if(_strToBuf.TryGetValue(name, let oldBuffer))
			{
				int index = GetIndexOfBuffer(oldBuffer);

				ref BufferEntry bufferDesc = ref _buffers[index];

				// If the names don't match something went spectactularly wrong.
				Log.EngineLogger.AssertDebug(name == bufferDesc.Name);

				oldBuffer?.ReleaseRef();
				
				buffer?.AddRef();
				bufferDesc.Buffer = buffer;

				_strToBuf[bufferDesc.Name] = buffer;
				_idxToBuf[bufferDesc.Index] = buffer;

				return true;
			}
			else
			{
				return false;
			}
		}

		public void Add(int index, String name, Buffer buffer)
		{
			String nameStr = new String(name);
			BufferEntry entry = (nameStr, index, buffer);

			buffer.AddRef();
			_buffers.Add(entry);
			_strToBuf.Add(entry.Name, entry.Buffer);
			_idxToBuf.Add(entry.Index, entry.Buffer);
		}

		/**
		 * Returns the index of the given Buffer in the _buffer-List.
		 * @param The buffer to find the index of.
		 * @returns The index of the buffer in the _buffer-List, or -1 if it isn't in the list.
		 */
		int GetIndexOfBuffer(Buffer buffer)
		{
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
	}
}

using System;
using System.Collections;

namespace GlitchyEngine.Renderer
{
	public class BufferCollection
	{
		typealias BufferEntry = (String Name, int Index, Buffer Buffer, bool OwnsBuffer);

		List<BufferEntry> _buffers ~ delete:append _;

		Dictionary<StringView, Buffer> _strToBuf ~ delete:append _;
		Dictionary<int, Buffer> _idxToBuf ~ delete:append _;

		[AllowAppend]
		public this()
		{
			let buffers = append List<BufferEntry>();
			let strToBuf = append Dictionary<StringView, Buffer>();
			let idxToBuf = append Dictionary<int, Buffer>();

			_buffers = buffers;
			_strToBuf = strToBuf;
			_idxToBuf = idxToBuf;
		}

		public ~this()
		{
			for(let entry in _buffers)
			{
				delete entry.Name;
				if(entry.OwnsBuffer)
					delete entry.Buffer;
			}
		}

		public Buffer this[int idx] => _idxToBuf[idx];
		public Buffer this[StringView name] => _strToBuf[name];

		/**
		 * Replaces the buffer with the given index.
		 * @param idx The index (shader buffer register) of the buffer to replace.
		 * @param buffer The new buffer.
		 * @param If set to true, the Collection will take ownership of the buffer; if false, the ownership will remain with the caller.
		 */
		public void ReplaceBuffer(int idx, Buffer buffer, bool passOwnership = false)
		{
			if(_idxToBuf.TryGetValue(idx, let oldBuffer))
			{
				int index = GetIndexOfBuffer(oldBuffer);

				ref BufferEntry bufferDesc = ref _buffers[index];

				Log.EngineLogger.Assert(idx == bufferDesc.Index);

				if(bufferDesc.OwnsBuffer)
					delete bufferDesc.Buffer;

				bufferDesc.Buffer = buffer;
				bufferDesc.OwnsBuffer = passOwnership;

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
		 * @param If set to true, the Collection will take ownership of the buffer; if false, the ownership will remain with the caller.
		 */
		public void ReplaceBuffer(StringView name, Buffer buffer, bool passOwnership = false)
		{
			if(_strToBuf.TryGetValue(name, let oldBuffer))
			{
				int index = GetIndexOfBuffer(oldBuffer);

				ref BufferEntry bufferDesc = ref _buffers[index];

				Log.EngineLogger.Assert(name == bufferDesc.Name);

				if(bufferDesc.OwnsBuffer)
					delete bufferDesc.Buffer;

				bufferDesc.Buffer = buffer;
				bufferDesc.OwnsBuffer = passOwnership;

				_strToBuf[bufferDesc.Name] = buffer;
				_idxToBuf[bufferDesc.Index] = buffer;
			}
			else
			{
				Log.EngineLogger.Assert(false, "No buffer with the given name.");
			}
		}

		public void Add(int index, StringView name, Buffer buffer, bool passOwnership = false)
		{
			String nameStr = new String(name);
			BufferEntry entry = (nameStr, index, buffer, passOwnership);

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

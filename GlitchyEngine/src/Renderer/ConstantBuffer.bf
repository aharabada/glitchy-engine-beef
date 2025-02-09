using System;
using GlitchyEngine.Math;
using DirectX.D3D11Shader;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	public class ConstantBuffer : Buffer
	{
		protected String _name ~ delete _;

		/**
		 * The buffer that contains the buffer data on the CPU.
		 */
		protected internal uint8[] rawData ~ delete _;

		protected BufferVariableCollection _variables = new BufferVariableCollection() ~ delete _;

		protected bool _isDirty = true;

		protected internal int _generation = 0;

		/// Gets the name of the constant buffer.
		public StringView Name => _name;

		public BufferVariableCollection Variables => _variables;

		/// Gets a span to the rawData held on the CPU.
		public Span<uint8> RawData => rawData;

		protected this() {}

		public this(StringView name, int64 size)
		{
			_name = new String(name);
			rawData = new uint8[size];
			ConstructBuffer();
		}

		protected internal void AddVariable(BufferVariable ownVariable)
		{
			_variables.Add(ownVariable);
		}

		public void AddVariable(StringView name, uint64 offset, uint64 sizeInBytes, bool isUsed, ShaderVariableType type, uint8 rows, uint8 columns, uint64 arraySize)
		{
			_variables.Add(new BufferVariable(name, this, type, columns, rows, (uint32)offset, (uint32)sizeInBytes, (uint32)arraySize, isUsed));
		}

		/**
		 * Construct the buffer description.
		 */
		protected void ConstructBuffer()
		{
			_description.Size = (.)rawData.Count;
			_description.BindFlags = .Constant;
			_description.CPUAccess = .Write;
			_description.Usage = .Dynamic;
			_description.MiscFlags = .None;
		}

		/**
		 * Uploads the date to the GPU.
		 * @returns true if the GPU buffer was updated, false otherwise (i.e. it wasn't dirty).
		 */
		public virtual Result<void> Apply()
		{
			bool isDirty = false;

			for (BufferVariable variable in _variables)
			{
				if (variable.IsDirty)
				{
					isDirty = true;					
					Enum.ClearFlag(ref variable.[Friend]_flags, .Dirty);
				}
			}

			if (isDirty)
			{
				Result<void> setDataResult = PlatformSetData(rawData.CArray(), (uint32)rawData.Count, 0, .WriteDiscard);
	
				if (setDataResult case .Err)
					return .Err;
				
				_generation++;
			}

			return .Ok;
		}
	}

	public enum ShaderVariableType
	{
		case Bool;
		case Float;
		case Int;
		case UInt;
		// todo

		public int ElementSizeInBytes()
		{
			switch (this)
			{
			case .Bool:
				// TODO: I'm pretty sure this is wrong and should be 4 as well!
				return 1;
			case .Float:
				return 4;
			case .Int:
				return 4;
			case .UInt:
				return 4;
			default:
				return 0;
			}
		}
	}
}

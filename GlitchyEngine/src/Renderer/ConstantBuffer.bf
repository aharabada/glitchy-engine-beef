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

		/// Gets the name of the constant buffer.
		public String Name => _name;

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
		 */
		public Result<void> Update()
		{
			return PlatformSetData(rawData.CArray(), (uint32)rawData.Count, 0, .WriteDiscard);
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

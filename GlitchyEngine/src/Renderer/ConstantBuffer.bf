using DirectX.D3D11Shader;
using System;
using System.Collections;
using GlitchyEngine.Math;

using internal GlitchyEngine.Renderer;

namespace GlitchyEngine.Renderer
{
	public class BufferVariableCollection : IEnumerable<BufferVariable>
	{
		protected bool _ownsVariables = true;
		protected List<BufferVariable> _variables = new .();
		protected Dictionary<String, BufferVariable> _nameToVariable = new .() ~ delete _;

		public this(bool ownsVariables = true)
		{
			_ownsVariables = ownsVariables;
		}

		public ~this()
		{
			if(_ownsVariables)
				DeleteContainerAndItems!(_variables);
			else
				delete _variables;
		}

		public void Add(BufferVariable ownVariable)
		{
			_variables.Add(ownVariable);
			_nameToVariable.Add(ownVariable.Name, ownVariable);
		}

		public bool TryAdd(BufferVariable ownVariable)
		{
			if(_nameToVariable.TryAdd(ownVariable.Name, ownVariable))
			{
				_variables.Add(ownVariable);
				return true;
			}
			else
			{
				return false;
			}
		}

		public bool TryGetVariable(String name, out BufferVariable variable)
		{
			return _nameToVariable.TryGetValue(name, out variable);
		}

		public BufferVariable this[String name] => _nameToVariable[name];

		public List<BufferVariable>.Enumerator GetEnumerator()
		{
			return _variables.GetEnumerator();
		}
	}

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

		protected this() {}

		protected internal void AddVariable(BufferVariable ownVariable)
		{
			_variables.Add(ownVariable);
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
		public void Update()
		{
			PlatformSetData(rawData.CArray(), (uint32)rawData.Count, 0, .WriteDiscard);
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

using System;
using System.Collections;

namespace GlitchyEngine.Renderer;

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

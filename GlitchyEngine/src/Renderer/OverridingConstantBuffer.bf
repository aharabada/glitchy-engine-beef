using System;

namespace GlitchyEngine.Renderer;

using internal GlitchyEngine.Renderer;

class OverridingConstantBuffer : ConstantBuffer
{
	protected ConstantBuffer _parent;

	protected int _parentGeneration = 0;

	public ConstantBuffer Parent => _parent;

	public this(ConstantBuffer parent) : base(parent.Name, parent.RawData.Length, parent.EngineBufferName)
	{
		Log.EngineLogger.AssertDebug(parent != null);
		_parent = parent;

		InheritVariables();
	}

	private void InheritVariables()
	{
		for (BufferVariable parentVariable in _parent.Variables)
		{
			BufferVariable newVariable = new BufferVariable(parentVariable.Name, this, parentVariable.ElementType, parentVariable.Columns,
				parentVariable.Rows, parentVariable.Offset, parentVariable._sizeInBytes, parentVariable.ArrayElements, parentVariable.IsUsed, parentVariable.PreviewName, parentVariable.EditorTypeName);

			if (parentVariable.Flags.HasFlag(.Locked))
			{
				Enum.SetFlag(ref newVariable.[Friend]_flags, .Readonly | .Locked);  
			}

			// Default to using the value from the parent buffer.
			Enum.SetFlag(ref newVariable.[Friend]_flags, .Unset);

			_variables.Add(newVariable);
		}
	}

	/**
	 * Uploads the date to the GPU.	 
	 * @returns true if the GPU buffer was updated, false otherwise (i.e. it wasn't dirty).
	 */
	public override Result<void> Apply()
	{
		Result<void> parentChangedResult = _parent.Apply();

		if (parentChangedResult case .Err)
			return .Err;

		bool isDirty = false;

		// If the parent got a newer generation then it was changed since our last apply.
		if (_parentGeneration != _parent._generation)
		{		
			uint8[] newData = scope uint8[rawData.Count];

			isDirty = true;
			_parent.RawData.CopyTo(newData);
			
			for (BufferVariable variable in _variables)
			{
				Enum.ClearFlag(ref variable.[Friend]_flags, .Dirty);
				// TODO: Check if our variable is 

				if (!variable.Flags.HasFlag(.Unset))
				{
					Internal.MemCpy(newData.Ptr + variable.Offset, variable.firstByte, variable._sizeInBytes);
				}
			}

			newData.CopyTo(rawData);
		}
		else
		{
			for (BufferVariable variable in _variables)
			{
				if (variable.IsDirty)
				{
					isDirty = true;
					Enum.ClearFlag(ref variable.[Friend]_flags, .Dirty);

					if (variable.Flags.HasFlag(.Unset))
					{
						// If it is unset, we copy the value from the parent buffer into ourselves.
						Internal.MemCpy(variable.firstByte, _parent.rawData.Ptr + variable.Offset, variable._sizeInBytes);
					}
				}
			}
		}
		
		if (isDirty)
		{
			Result<void> setDataResult = PlatformSetData(rawData.Ptr, (uint32)rawData.Count, 0, .WriteDiscard);

			if (setDataResult case .Err)
				return .Err;

			_generation++;
		}

		return .Ok;
	}
}
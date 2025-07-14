using System;
using Mono;
using GlitchyEngine.Core;
using System.Diagnostics;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

class EntityEditorWrapper : NewScriptClass
{
	function void ShowEntityEditorFunc(UUID entityId);

	private ShowEntityEditorFunc _showEntityEditorFunc;

	[AllowAppend]
	public this() : base(FullName, .Empty, .None, false)
	{
		CoreClrHelper.GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "ShowEntityEditor", out _showEntityEditorFunc);

		Debug.Assert(_showEntityEditorFunc != null);
	}

	public void ShowEntityEditor(NewScriptInstance instance, UUID entityId)
	{
		_showEntityEditorFunc(entityId);
	}
}

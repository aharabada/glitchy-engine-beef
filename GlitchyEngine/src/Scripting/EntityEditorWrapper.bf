using System;
using Mono;
using GlitchyEngine.Core;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

class EntityEditorWrapper : ScriptClass
{
	function void ShowEntityEditorFunc(MonoObject* scriptInstance, MonoException** exception);

	private ShowEntityEditorFunc _showEntityEditorFunc;

	[AllowAppend]
	public this(StringView classNamespace, StringView className, MonoImage* image) : base(classNamespace, className, image)
	{
		_showEntityEditorFunc = (ShowEntityEditorFunc)GetMethodThunk("ShowEntityEditor", 1);
		
		if (_showEntityEditorFunc == null)
		{
			Log.EngineLogger.Error("Entity editor has no show entity editor func.");
		}
	}

	public void ShowEntityEditor(ScriptInstance instance, UUID entityId)
	{
		MonoException* exception = null;

		_showEntityEditorFunc(instance.MonoInstance, &exception);

		if (exception != null)
		{
			ScriptEngine.HandleMonoException(exception, entityId);
		}
	}
}

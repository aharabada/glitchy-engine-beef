using System;
using GlitchyEngine.Core;
using GlitchyEngine.Scripting.Classes;

using static GlitchyEngine.Scripting.ScriptEngine;

namespace GlitchyEngine.Scripting;

class NewScriptClass
{
	public String FullName ~ delete _;
	public StringView Name;
	public Guid Guid;
	public ScriptMethods Methods;
	
	public bool RunInEditMode;

	public this(StringView fullName, Guid guid, ScriptMethods methods, bool runInEditMode = false)
	{
		// TODO: Remove the need for null termination
		FullName = new String(fullName)..EnsureNullTerminator();
		Guid = guid;

		int lastDotIndex = FullName.LastIndexOf('.');

		if (lastDotIndex == -1)
			Name = FullName;
		else
			Name = FullName.Substring(lastDotIndex + 1);

		Methods = methods;

		RunInEditMode = runInEditMode;
	}
}

using internal GlitchyEngine.Scripting;

class NewScriptInstance : RefCounter
{
	private NewScriptClass _scriptClass;

	private UUID _entityId;

	private bool _isCreated = false;

	public NewScriptClass ScriptClass => _scriptClass;

	/// Gets whether or not the instance has ben initialized.
	public bool IsInitialized {get; private set;};

	/// Gets whether or not the Create-Method of this instance has been called before.
	public bool IsCreated => _isCreated;

	public UUID EntityId => _entityId;

	public this(UUID entityId, NewScriptClass scriptClass)
	{
		Log.EngineLogger.AssertDebug(scriptClass != null);

		_entityId = entityId;
		_scriptClass = scriptClass;
	}

	public ~this()
	{
		Destroy();
	}

	public void Instantiate()
	{
		CoreClrHelper.CreateScriptInstance(_entityId, _scriptClass.FullName);
		IsInitialized = true;
	}

	public void InvokeOnCreate()
	{
		if (_scriptClass.Methods.HasFlag(.OnCreate))
		{
			CoreClrHelper._entityScriptFunctions.OnCreate(_entityId);
			_isCreated = true;
		}
	}

	public void InvokeOnUpdate(float deltaTime)
	{
		if (_scriptClass.Methods.HasFlag(.OnUpdate))
			CoreClrHelper._entityScriptFunctions.OnUpdate(_entityId, deltaTime);
	}

	public void Destroy()
	{
		if (IsInitialized)
		{
			// We always need to do some cleanup on the script side, but we pass over whether the script wants/needs its OnDelete called
			CoreClrHelper._entityScriptFunctions.OnDestroy(_entityId, (ScriptEngine.ApplicationInfo.IsInPlayMode || ScriptClass.RunInEditMode));
	
			IsInitialized = false;
		}

		ScriptEngine.UnregisterScriptInstance(_entityId);
	}
}
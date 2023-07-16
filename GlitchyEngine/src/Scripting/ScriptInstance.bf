using Mono;
using GlitchyEngine.Core;
using System;

namespace GlitchyEngine.Scripting;

class ScriptInstance : RefCounter
{
	private ScriptClass _scriptClass;

	private MonoObject* _instance;
	private uint32 _gcHandle;

	public ScriptClass ScriptClass => _scriptClass;
	
	/// Gets whether or not the instance has ben initialized.
	public bool IsInitialized => _instance != null;

	/// Gets whether or not the Create-Method of this instance has been called before.
	public bool IsCreated => _isCreated;
	
	private bool _isCreated = false;

	public this(ScriptClass scriptClass)
	{
		Log.EngineLogger.AssertDebug(scriptClass != null);
		_scriptClass = scriptClass..AddRef();
	}

	private ~this()
	{
		if (_instance != null)
		{
			_scriptClass.OnDestroy(_instance);
			Mono.mono_gchandle_free(_gcHandle);
		}
		_scriptClass?.ReleaseRef();
	}

	public void Instantiate(UUID uuid)
	{
		_instance = _scriptClass.CreateInstance(uuid);
		_gcHandle = Mono.mono_gchandle_new(_instance, true);
	}

	public void InvokeOnCreate()
	{
		_scriptClass.OnCreate(_instance);
		_isCreated = true;
	}

	public void InvokeOnUpdate(float deltaTime)
	{
		_scriptClass.OnUpdate(_instance, deltaTime);
	}

	public void InvokeOnDestroy()
	{
		_scriptClass.OnDestroy(_instance);
	}

	public T GetFieldValue<T>(ScriptField field)
	{
		return _scriptClass.GetFieldValue<T>(_instance, field.[Friend]_monoField);
	}

	public void SetFieldValue<T>(ScriptField field, in T value)
	{
		_scriptClass.SetFieldValue<T>(_instance, field.[Friend]_monoField, value);
	}
}
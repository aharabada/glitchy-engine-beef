using Mono;
using GlitchyEngine.Core;

namespace GlitchyEngine.Scripting;

class ScriptInstance : RefCounter
{
	private ScriptClass _scriptClass;

	private MonoObject* _instance;
	private uint32 _gcHandle;

	public ScriptClass ScriptClass => _scriptClass;

	public bool IsInstatiated => _instance != null;

	public this(ScriptClass scriptClass)
	{
		Log.EngineLogger.AssertDebug(scriptClass != null);
		_scriptClass = scriptClass;
	}

	private ~this()
	{
		if (_instance != null)
		{
			_scriptClass.OnDestroy(_instance);
			Mono.mono_gchandle_free(_gcHandle);
		}
	}

	public void Instantiate(UUID uuid)
	{
		_instance = _scriptClass.CreateInstance(uuid);
		_gcHandle = Mono.mono_gchandle_new(_instance, true);
	}

	public void InvokeOnCreate()
	{
		_scriptClass.OnCreate(_instance);
	}

	public void InvokeOnUpdate(float deltaTime)
	{
		_scriptClass.OnUpdate(_instance, deltaTime);
	}

	public void InvokeOnDestroy()
	{
		_scriptClass.OnDestroy(_instance);
	}
}
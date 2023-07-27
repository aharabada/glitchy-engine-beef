using Mono;
using GlitchyEngine.Core;
using System;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

class ScriptInstance : RefCounter
{
	private ScriptClass _scriptClass;

	private MonoObject* _instance;
	private uint32 _gcHandle;

	private UUID _entityId;

	public ScriptClass ScriptClass => _scriptClass;
	
	/// Gets whether or not the instance has ben initialized.
	public bool IsInitialized => _instance != null;

	/// Gets whether or not the Create-Method of this instance has been called before.
	public bool IsCreated => _isCreated;
	
	private bool _isCreated = false;

	internal MonoObject* MonoInstance => _instance;

	public UUID EntityId => _entityId;

	public this(UUID entityId, ScriptClass scriptClass)
	{
		Log.EngineLogger.AssertDebug(scriptClass != null);

		_entityId = entityId;
		_scriptClass = scriptClass..AddRef();
	}

	private ~this()
	{
		if (_instance != null)
		{
			InvokeOnDestroy();
			Mono.mono_gchandle_free(_gcHandle);
		}
		_scriptClass?.ReleaseRef();
	}

	public void Instantiate(UUID uuid)
	{
		_instance = _scriptClass.CreateInstance(uuid, let exception);
		_gcHandle = Mono.mono_gchandle_new(_instance, true);

		if (exception != null)
			ScriptEngine.HandleMonoException(exception, this);
	}

	public void InvokeOnCreate()
	{
		_scriptClass.OnCreate(_instance, let exception);
		_isCreated = true;
		
		if (exception != null)
			ScriptEngine.HandleMonoException(exception, this);
	}

	public void InvokeOnUpdate(float deltaTime)
	{
		_scriptClass.OnUpdate(_instance, deltaTime, let exception);
		
		if (exception != null)
			ScriptEngine.HandleMonoException(exception, this);
	}

	public void InvokeOnDestroy()
	{
		_scriptClass.OnDestroy(_instance, let exception);
		
		if (exception != null)
			ScriptEngine.HandleMonoException(exception, this);
	}

	public T GetFieldValue<T>(ScriptField field)
	{
		return _scriptClass.GetFieldValue<T>(_instance, field.[Friend]_monoField);
	}

	public void SetFieldValue<T>(ScriptField field, in T value)
	{
		_scriptClass.SetFieldValue<T>(_instance, field.[Friend]_monoField, value);
	}

	/// Creates a new instance of the given component class and initializes it for the current entity.
	public MonoObject* CreateComponentInstance(ScriptClass componentClassType)
	{
		MonoObject* componentInstance = componentClassType.CreateInstance();

		// TODO: We could cache the property, but this might be fine
		MonoProperty* entityProperty = Mono.mono_class_get_property_from_name(componentClassType.[Friend]_monoClass, "Entity");

		MonoObject* exception = null;

		Mono.mono_property_set_value(entityProperty, componentInstance, (void**)&_instance, &exception);

		if (exception != null)
			ScriptEngine.HandleMonoException((MonoException*)exception, this);

		return componentInstance;
	}
}
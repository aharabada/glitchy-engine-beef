using Mono;
using System;
using GlitchyEngine.Core;
using System.Collections;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

public struct ScriptField
{
	public StringView Name;
	internal MonoClassField* _monoField;

	internal this(StringView name, MonoClassField* monoField)
	{
		Name = name;
		_monoField = monoField;
	}
}

class ScriptClass : RefCounter
{
	private String _namespace ~ delete _;
	private String _className ~ delete _;
	private String _fullName ~ delete _;

	private MonoClass* _monoClass;

	//private List<MonoClassField*> _monoFields ~ delete _;
	private Dictionary<StringView, ScriptField> _monoFields ~ delete _;

	//typealias ConstructorMethod = function void(MonoObject* instance, UUID uuid, MonoException** exception);
	typealias OnCreateMethod = function MonoObject*(MonoObject* instance, MonoException** exception);
	typealias OnUpdateMethod = function MonoObject*(MonoObject* instance, float deltaTime, MonoException** exception);
	typealias OnDestroyMethod = function MonoObject*(MonoObject* instance, MonoException** exception);

	private MonoMethod* _constructor;
	//private ConstructorMethod _constructor;
	private OnCreateMethod _onCreate;
	private OnUpdateMethod _onUpdate;
	private OnDestroyMethod _onDestroy;

	public StringView Namespace => _namespace;
	public StringView ClassName => _className;
	public StringView FullName => _fullName;

	public Dictionary<StringView, ScriptField> Fields => _monoFields;

	[AllowAppend]
	public this(StringView classNamespace, StringView className)
	{
		_namespace = new String(classNamespace);
		_className = new String(className);
		_fullName = new $"{_namespace}.{_className}";

		_monoClass = Mono.mono_class_from_name(ScriptEngine.[Friend]s_CoreAssemblyImage, _namespace, _className);

		//_constructor = (ConstructorMethod)GetMethodThunk(".ctor", 1); // GetMethod(".ctor", 1);//
		_constructor = GetMethod(".ctor", 1);
		_onCreate = (OnCreateMethod)GetMethodThunk("OnCreate");
		_onUpdate = (OnUpdateMethod)GetMethodThunk("OnUpdate", 1);
		_onDestroy = (OnDestroyMethod)GetMethodThunk("OnDestroy");

		ExtractFields();
	}

	private void ExtractFields()
	{
		//_monoFields = new List<MonoClassField*>();´
		_monoFields = new Dictionary<StringView, ScriptField>();
		
		void* iterator = null;
		MonoClassField* currentField = null;
		while ((currentField = Mono.mono_class_get_fields(_monoClass, &iterator)) != null)
		{
			// TODO: does the pointer from mono really never move?
			StringView name = StringView(Mono.mono_field_get_name(currentField));

			_monoFields[name] = .(name, currentField);
		}
	}

	public void OnCreate(MonoObject* instance)
	{
		MonoException* exception = null;
		if (_onCreate != null)
			_onCreate(instance, &exception);
	}

	public void OnUpdate(MonoObject* instance, float deltaTime)
	{
		MonoException* exception;
		if (_onUpdate != null)
			_onUpdate(instance, deltaTime, &exception);
	}

	public void OnDestroy(MonoObject* instance)
	{
		MonoException* exception;
		if (_onDestroy != null)
			_onDestroy(instance, &exception);
	}

	public MonoObject* CreateInstance(UUID uuid)
	{
		MonoObject* instance = Mono.mono_object_new(ScriptEngine.[Friend]s_AppDomain, _monoClass);

#unwarn
		ScriptEngine.[Friend]s_EngineObject.Invoke(ScriptEngine.[Friend]s_EngineObject._constructor, instance, &uuid);

		//MonoException* exception = null;
//#unwarn
		//ScriptEngine.[Friend]s_EntityRoot._constructor(instance, uuid, &exception);
		//ScriptEngine.[Friend]s_EntityRoot.Invoke(_constructor, instance, &uuid);

		/*MonoObject* exception = null;
#unwarn*/
		//Mono.mono_runtime_invoke(_constructor, instance, (.)&uuid, &exception);
		//Mono.mono_runtime_object_init(instance);
		//MonoException* exception;
		//_constructor(instance, uuid, &exception);

		return instance;
	}

	public MonoMethod* GetMethod(StringView name, int argCount = 0)
	{
		return Mono.mono_class_get_method_from_name(_monoClass, name.ToScopeCStr!(), argCount);
	}

	public void* GetMethodThunk(StringView name, int argCount = 0)
	{
		MonoMethod* method = GetMethod(name, argCount);

		if (method == null)
			return null;

		return Mono.mono_method_get_unmanaged_thunk(method);
	}

	public MonoObject* Invoke(MonoMethod* method, MonoObject* instance, void** args = null)
 	{
		 MonoObject* exception = null;
		 return Mono.mono_runtime_invoke(method, instance, args, &exception);
	}

	public MonoObject* Invoke(MonoMethod* method, MonoObject* instance, params void*[] args)
 	{
		 return Mono.mono_runtime_invoke(method, instance, args.Ptr, null);
	}

	public T Invoke<T>(MonoMethod* method, MonoObject* instance, params void*[] args)
 	{
		 MonoObject* object = Invoke(method, instance, args.Ptr);
		 return *(T*)Mono.mono_object_unbox(object);
	}
}

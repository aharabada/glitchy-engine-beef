using Mono;
using System;
using GlitchyEngine.Core;
using System.Collections;
using GlitchyEngine.Scripting.Classes;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

class SharpClass : RefCounter
{
	protected String _fullName ~ delete:append _;

	protected StringView _namespace;
	protected StringView _className;
	
	protected internal MonoClass* _monoClass;
	
	public StringView Namespace => _namespace;
	public StringView ClassName => _className;
	public StringView FullName => _fullName;

	[AllowAppend]
	public this(StringView classNamespace, StringView className, MonoImage* image)
	{
		String fullName = append $"{classNamespace}.{className}";

		_fullName = fullName;
		_namespace = _fullName.Substring(0, classNamespace.Length);
		_className = _fullName.Substring(classNamespace.Length + 1);

		_monoClass = Mono.mono_class_from_name(image, _namespace.ToScopeCStr!(), _className.ToScopeCStr!());

		Log.EngineLogger.AssertDebug(_monoClass != null);
	}
}

class ScriptClass : SharpClass
{
	typealias OnCreateMethod = function MonoObject*(MonoObject* instance, MonoException** exception);
	typealias OnUpdateMethod = function MonoObject*(MonoObject* instance, float deltaTime, MonoException** exception);
	typealias OnDestroyMethod = function MonoObject*(MonoObject* instance, MonoException** exception);

	private bool _runInEditMode;

	private MonoMethod* _constructor;

	private OnCreateMethod _onCreate;
	private OnUpdateMethod _onUpdate;
	private OnDestroyMethod _onDestroy;
	
	private function [CallingConvention(.Cdecl)] MonoObject*(MonoObject* instance, MonoObject* collision2d, MonoException** exception) _onCollisionEnter2D;
	private function [CallingConvention(.Cdecl)] MonoObject*(MonoObject* instance, MonoObject* collision2d, MonoException** exception) _onCollisionLeave2D;

	public bool HasCollisionEnter2D => _onCollisionEnter2D != null;
	public bool HasCollisionLeave2D => _onCollisionLeave2D != null;

	public bool RunInEditMode => _runInEditMode;

	[AllowAppend]
	public this(StringView classNamespace, StringView className, MonoImage* image) :
		base(classNamespace, className, image)
	{
		_constructor = FindConstructor();
		_onCreate = (OnCreateMethod)GetMethodThunk("OnCreate");
		_onUpdate = (OnUpdateMethod)GetMethodThunk("OnUpdate", 1);
		_onDestroy = (OnDestroyMethod)GetMethodThunk("OnDestroy");

		_onCollisionEnter2D = (.)GetMethodThunk("OnCollisionEnter2D", 1);
		_onCollisionLeave2D = (.)GetMethodThunk("OnCollisionLeave2D", 1);

		DetermineRunInEditMode();
	}

	/// Determines whether or not scripts of this class will be executed in edit mode.
	private void DetermineRunInEditMode()
	{
		// TODO: This is only relevant for the editor!
		MonoCustomAttrInfo* attributes = Mono.mono_custom_attrs_from_class(_monoClass);

		if (attributes != null && ScriptEngine.Classes.RunInEditModeAttribute != null)
			_runInEditMode = Mono.mono_custom_attrs_has_attr(attributes, ScriptEngine.Classes.RunInEditModeAttribute._monoClass);
	}

	private MonoMethod* FindConstructor()
	{
		MonoMethod* constructor = null;

		MonoMethodDesc* constructorDesc = Mono.mono_method_desc_new(":.ctor(GlitchyEngine.Core.UUID)", true);
		
		// Entities usually don't have a constructor that takes the UUID, so we have to look for it in the parents.
		for (MonoClass* @class = _monoClass; @class != null; @class = Mono.mono_class_get_parent(@class))
		{
			constructor = Mono.mono_method_desc_search_in_class(constructorDesc, @class);

			if (constructor != null)
				break;
		}

		Mono.mono_method_desc_free(constructorDesc);

		return constructor;
	}

	private void CallConstructorChain(MonoObject* instance, UUID uuid, out MonoException* exception)
	{
		exception = null;

		if (_constructor == null)
			return;

#unwarn
		void*[1] args = void*[](&uuid);

		Mono.mono_runtime_invoke(_constructor, instance, &args, (.)&exception);
	}

	public void OnCreate(MonoObject* instance, out MonoException* exception)
	{
		exception = null;

		if (_onCreate != null)
			_onCreate(instance, &exception);
	}

	public void OnUpdate(MonoObject* instance, float deltaTime, out MonoException* exception)
	{
		exception = null;

		if (_onUpdate != null)
			_onUpdate(instance, deltaTime, &exception);
	}

	public void OnDestroy(MonoObject* instance, out MonoException* exception)
	{
		exception = null;

		if (_onDestroy != null)
			_onDestroy(instance, &exception);
	}
	
	public void OnCollisionEnter2D(MonoObject* instance, Collision2D collision, out MonoException* exception)
	{
		exception = null;

		if (_onCollisionEnter2D != null)
		{
			MonoObject* monoObject = ScriptEngine.Classes.Collision2D.BoxValue(collision);
			_onCollisionEnter2D(instance, monoObject, &exception);
		}
	}
	
	public void OnCollisionLeave2D(MonoObject* instance, Collision2D collision, out MonoException* exception)
	{
		exception = null;
		
		if (_onCollisionEnter2D != null)
		{
			MonoObject* monoObject = ScriptEngine.Classes.Collision2D.BoxValue(collision);
			_onCollisionLeave2D(instance, monoObject, &exception);
		}
	}

	public MonoObject* CreateInstance(UUID uuid, out MonoException* exception)
	{
		MonoObject* instance = Mono.mono_object_new(ScriptEngine.[Friend]s_AppDomain, _monoClass);

		// Invoke empty constructor to initialize fields with default values specified in the script itself
		Mono.mono_runtime_object_init(instance);

		// Invoke UUID Constructors:
		CallConstructorChain(instance, uuid, out exception);

		// Invoke constructor with UUID
//#unwarn
		//ScriptEngine.[Friend]s_EngineObject.Invoke(ScriptEngine.[Friend]s_EngineObject._constructor, instance, out exception, &uuid);

		return instance;
	}

	public MonoObject* CreateInstance()
	{
		MonoObject* instance = Mono.mono_object_new(ScriptEngine.[Friend]s_AppDomain, _monoClass);

		// Invoke empty constructor to fill fields
		Mono.mono_runtime_object_init(instance);

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

		 MonoObject* result = Mono.mono_runtime_invoke(method, instance, args, &exception);

		 if (exception != null)
			 ScriptEngine.HandleMonoException((MonoException*)exception);

		 return result;
	}

	public MonoObject* Invoke(MonoMethod* method, MonoObject* instance, out MonoException* exception, params void*[] args)
 	{
		exception = null;

		MonoObject* result = Mono.mono_runtime_invoke(method, instance, args.Ptr, (.)&exception);

		return result;
	}

	public T Invoke<T>(MonoMethod* method, MonoObject* instance, params void*[] args)
 	{
		 MonoObject* object = Invoke(method, instance, args.Ptr);
		 return *(T*)Mono.mono_object_unbox(object);
	}

	public MonoObject* BoxValue<T>(in T value)
	{
		return Mono.mono_value_box(ScriptEngine.[Friend]s_AppDomain, _monoClass, &value);
	}

	public MonoObject* BoxValue(void* value)
	{
		return Mono.mono_value_box(ScriptEngine.[Friend]s_AppDomain, _monoClass, value);
	}
}

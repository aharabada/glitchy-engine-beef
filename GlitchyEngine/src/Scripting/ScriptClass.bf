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
	public bool IsStatic;
	public ScriptFieldType FieldType;

	internal this(StringView name, MonoClassField* monoField, bool isStatic, ScriptFieldType fieldType)
	{
		Name = name;
		_monoField = monoField;
		IsStatic = isStatic;
		FieldType = fieldType;
	}
}

public struct ScriptFieldInstance
{
	public ScriptFieldType Type;
	// TODO: I hate this, but we need to be able to store an entire matrix
	internal uint8[sizeof(GlitchyEngine.Math.Matrix)] _data;

	public this(ScriptFieldType type)
	{
		Type = type;
		_data = default;
	}

	public T GetData<T>()
	{
#unwarn
		return *(T*)&_data;
	}
	
	public void SetData<T>(T value) mut
	{
		*(T*)&_data = value;
	}
}

public typealias ScriptFieldMap = Dictionary<String, ScriptFieldInstance>;

abstract class SharpType : RefCounter
{
	protected String _namespace ~ delete _;
	protected String _className ~ delete _;
	protected String _fullName ~ delete _;
	protected ScriptFieldType _scriptType;
	
	protected Dictionary<StringView, ScriptField> _monoFields ~ delete _;

	public StringView Namespace => _namespace;
	public StringView ClassName => _className;
	public StringView FullName => _fullName;
	public ScriptFieldType ScriptType => _scriptType;
	
	public Dictionary<StringView, ScriptField> Fields => _monoFields;
	
	public this(StringView classNamespace, StringView className, ScriptFieldType scriptType)
	{
		_namespace = new String(classNamespace);
		_className = new String(className);
		_fullName = new $"{_namespace}.{_className}";
		_scriptType = scriptType;
		
		ScriptEngine.RegisterSharpType(this);
	}
}

class SharpClass : SharpType
{
	protected internal MonoClass* _monoClass;
	
	public this(StringView classNamespace, StringView className, MonoImage* image, ScriptFieldType fieldType = .Class) :
		base(classNamespace, className, fieldType)
	{
		_monoClass = Mono.mono_class_from_name(image, _namespace, _className);

		Log.EngineLogger.AssertDebug(_monoClass != null);

		ExtractFields();
	}

	internal bool IsType(MonoType* type)
	{
		return Mono.mono_class_get_type(_monoClass) == type;
	}

	private void ExtractFields()
	{
		//_monoFields = new List<MonoClassField*>();´
		_monoFields = new Dictionary<StringView, ScriptField>();
		
		void* iterator = null;
		MonoClassField* currentField = null;
		while ((currentField = Mono.mono_class_get_fields(_monoClass, &iterator)) != null)
		{
			StringView name = StringView(Mono.mono_field_get_name(currentField));

			MonoType* type = Mono.mono_field_get_type(currentField);

			ScriptFieldType fieldType = ScriptEngineHelper.GetScriptFieldType(type);

			// If field type is none the field might be a struct, class or enum
			if (fieldType == .None)
			{
				SharpType sharpType = ScriptEngine.GetSharpType(type);
				fieldType = sharpType?.ScriptType ?? .None;
				
				if (sharpType == null)
					continue;

				sharpType.ReleaseRef();
			}

			//Mono.MonoTypeEnum fieldType = Mono.Mono.mono_type_get_type(type);

			FieldAttribute flags = (.)Mono.mono_field_get_flags(currentField);

			MonoCustomAttrInfo* attributes = Mono.mono_custom_attrs_from_field(_monoClass, currentField);

			if (flags.HasFlag(.Public) ||
				(attributes != null &&
				Mono.mono_custom_attrs_has_attr(attributes, ScriptEngine.Attributes.s_ShowInEditorAttribute)))
			{
				_monoFields[name] = .(name, currentField, flags.HasFlag(.Static), fieldType);
			}
		}
	}
}

class SharpStruct : SharpClass
{
	protected int _size;

	public int Size => _size;

	public this(StringView classNamespace, StringView className, MonoImage* image)
		: base(classNamespace, className, image)
	{

	}
}

class ScriptClass : SharpClass
{
	/*private String _namespace ~ delete _;
	private String _className ~ delete _;
	private String _fullName ~ delete _;

	private MonoClass* _monoClass;

	//private List<MonoClassField*> _monoFields ~ delete _;
	private Dictionary<StringView, ScriptField> _monoFields ~ delete _;*/

	//typealias ConstructorMethod = function void(MonoObject* instance, UUID uuid, MonoException** exception);
	typealias OnCreateMethod = function MonoObject*(MonoObject* instance, MonoException** exception);
	typealias OnUpdateMethod = function MonoObject*(MonoObject* instance, float deltaTime, MonoException** exception);
	typealias OnDestroyMethod = function MonoObject*(MonoObject* instance, MonoException** exception);

	private MonoMethod* _constructor;
	//private ConstructorMethod _constructor;
	private OnCreateMethod _onCreate;
	private OnUpdateMethod _onUpdate;
	private OnDestroyMethod _onDestroy;

	/*public StringView Namespace => _namespace;
	public StringView ClassName => _className;
	public StringView FullName => _fullName;

	public Dictionary<StringView, ScriptField> Fields => _monoFields;*/

	[AllowAppend]
	public this(StringView classNamespace, StringView className, MonoImage* image) :
		base(classNamespace, className, image)
	{
		//_constructor = (ConstructorMethod)GetMethodThunk(".ctor", 1); // GetMethod(".ctor", 1);//
		_constructor = GetMethod(".ctor", 1);
		_onCreate = (OnCreateMethod)GetMethodThunk("OnCreate");
		_onUpdate = (OnUpdateMethod)GetMethodThunk("OnUpdate", 1);
		_onDestroy = (OnDestroyMethod)GetMethodThunk("OnDestroy");
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

		// TODO: I think this is a bit dirty
		// Invoke empty constructor to fill fields
		Mono.mono_runtime_object_init(instance);

		// Invoke constructor with UUID
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

	public T GetFieldValue<T>(MonoObject* instance, MonoClassField* field)
	{
		T value = default;
		Mono.Mono.mono_field_get_value(instance, field, &value);
		return value;
	}

	public void SetFieldValue<T>(MonoObject* instance, MonoClassField* field, in T value)
	{
		Mono.Mono.mono_field_set_value(instance, field, &value);
	}
}

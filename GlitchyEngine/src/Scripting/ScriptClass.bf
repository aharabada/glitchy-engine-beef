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
	public SharpType SharpType;

	internal this(StringView name, MonoClassField* monoField, bool isStatic, ScriptFieldType fieldType, SharpType sharpType)
	{
		Name = name;
		_monoField = monoField;
		IsStatic = isStatic;
		FieldType = fieldType;
		SharpType = sharpType;
	}

	public bool IsType(SharpClass otherClass, bool checkIfSubtype)
	{
		return IsType(otherClass.GetMonoType(), checkIfSubtype);
	}

	public bool IsType(MonoType* otherType, bool checkIfSubtype)
	{
		MonoType* myType = GetMonoType();

		if (checkIfSubtype)
		{
			MonoClass* myClass = Mono.mono_type_get_class(myType);
			MonoClass* otherClass = Mono.mono_type_get_class(otherType);

			return Mono.mono_class_is_subclass_of(myClass, otherClass, false);
		}
		else
		{
			return myType == otherType;
		}
	}

	public MonoType* GetMonoType()
	{
		return Mono.mono_field_get_type(_monoField);
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

	internal MonoType* GetMonoType()
	{
		return Mono.mono_class_get_type(_monoClass);
	}

	internal bool IsType(MonoType* type)
	{
		return GetMonoType() == type;
	}

	internal bool IsSubclass(MonoClass* @class)
	{
		return Mono.mono_class_is_subclass_of(_monoClass, @class, false);
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

			SharpType sharpType = null;

			// If field type is none the field might be a struct, class or enum
			if (fieldType == .None)
			{
				sharpType = ScriptEngine.GetSharpType(type);
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
				_monoFields[name] = .(name, currentField, flags.HasFlag(.Static), fieldType, sharpType);
			}
		}
	}
}

struct EnumValue
{
	public StringView Name;

	public uint64 Value;

	public this(StringView name, uint64 value)
	{
		Name = name;
		Value = value;
	}
}

class SharpEnum : SharpClass
{
	private append Dictionary<uint64, EnumValue> _values = .();

	public Dictionary<uint64, EnumValue> Values => _values;

	private int _underlyingSize = 0;

	public this(StringView classNamespace, StringView className, MonoImage* image)
		: base(classNamespace, className, image, .Enum)
	{
		ExtractEnumValues();
	}

	private void ExtractEnumValues()
	{
		_underlyingSize = Mono.mono_class_instance_size(_monoClass);
		Log.EngineLogger.Assert(_underlyingSize != 0);

		var vtable = Mono.mono_class_vtable(ScriptEngine.[Friend]s_AppDomain, _monoClass);

		void* iterator = null;
		MonoClassField* currentField = null;
		while ((currentField = Mono.mono_class_get_fields(_monoClass, &iterator)) != null)
		{
			MonoType* fieldType = Mono.mono_field_get_type(currentField);
			MonoClass* fieldClass = Mono.mono_type_get_class(fieldType);

			FieldAttribute fieldFlags = (.)Mono.mono_field_get_flags(currentField);

			if (fieldFlags.HasFlag(.Public) && fieldFlags.HasFlag(.Static) &&
				fieldClass != null && Mono.mono_class_is_subclass_of(fieldClass, _monoClass, false))
			{
				StringView fieldName = StringView(Mono.mono_field_get_name(currentField));

				uint64 value = 0;
				Mono.mono_field_static_get_value(vtable, currentField, &value);

				EnumValue enumValue = .(fieldName, value);
	
				_values.Add(value, enumValue);
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
	public this(StringView classNamespace, StringView className, MonoImage* image, ScriptFieldType scriptFieldType = .Class) :
		base(classNamespace, className, image, scriptFieldType)
	{
		//_constructor = (ConstructorMethod)GetMethodThunk(".ctor", 1); // GetMethod(".ctor", 1);//
		_constructor = GetMethod(".ctor", 1);
		_onCreate = (OnCreateMethod)GetMethodThunk("OnCreate");
		_onUpdate = (OnUpdateMethod)GetMethodThunk("OnUpdate", 1);
		_onDestroy = (OnDestroyMethod)GetMethodThunk("OnDestroy");
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

	public MonoObject* CreateInstance(UUID uuid, out MonoException* exception)
	{
		MonoObject* instance = Mono.mono_object_new(ScriptEngine.[Friend]s_AppDomain, _monoClass);

		// Invoke empty constructor to fill fields
		Mono.mono_runtime_object_init(instance);

		// Invoke constructor with UUID
#unwarn
		ScriptEngine.[Friend]s_EngineObject.Invoke(ScriptEngine.[Friend]s_EngineObject._constructor, instance, out exception, &uuid);

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

	public T GetFieldValue<T>(MonoObject* instance, MonoClassField* field)
	{
		T value = default;
		Mono.mono_field_get_value(instance, field, &value);
		return value;
	}

	public void SetFieldValue<T>(MonoObject* instance, MonoClassField* field, in T value)
	{
		Mono.mono_field_set_value(instance, field, &value);
	}

	public void SetFieldValue<T>(MonoObject* instance, MonoClassField* field, in T value) where T : struct*
	{
		Mono.mono_field_set_value(instance, field, value);
	}
}

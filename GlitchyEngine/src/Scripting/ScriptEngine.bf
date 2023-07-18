using Mono;
using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using GlitchyEngine.World;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

static sealed class ScriptEngineHelper
{
	private static Dictionary<StringView, ScriptFieldType> _scriptFieldTypes = new Dictionary<StringView, ScriptFieldType>()
	{
		("System.Boolean", .Bool),

		("System.SByte", .SByte),
		("System.Int16", .Short),
		("System.Int32", .Int),
		("System.Int64", .Long),
		
		("System.Byte", .Byte),
		("System.UInt16", .UShort),
		("System.UInt32", .UInt),
		("System.UInt64", .ULong),

		("System.Single", .Float),
		// TODO: We probably want to switch the C#-Library to use the superior floatN-Names
		("GlitchyEngine.Math.Vector2", .float2),
		("GlitchyEngine.Math.Vector3", .float3),
		("GlitchyEngine.Math.Vector4", .float4),

		("System.Double", .Double),

		("GlitchyEngine.Entity", .Entity),
	} ~ delete _;

	public static ScriptFieldType GetScriptFieldType(MonoType* monoType)
	{
		StringView typeName = StringView(Mono.mono_type_get_name(monoType));

		return _scriptFieldTypes.TryGetValue(typeName, .. let scriptFieldType);
	}
}

static class ScriptEngine
{
	private static MonoDomain* s_RootDomain;
	private static MonoDomain* s_AppDomain;

	private static MonoAssembly* s_CoreAssembly;
	private static MonoImage* s_CoreAssemblyImage;

	private static MonoAssembly* s_AppAssembly;
	private static MonoImage* s_AppAssemblyImage;

	private static Scene s_Context ~ _?.ReleaseRef();

	private static ScriptClass s_EntityRoot ~ _?.ReleaseRef();
	private static ScriptClass s_EngineObject ~ _?.ReleaseRef();

	private static Dictionary<StringView, SharpType> _sharpClasses = new .() ~ DeleteDictionaryAndReleaseValues!(_);
	
	private static Dictionary<StringView, ScriptClass> _entityScripts = new .() ~ DeleteDictionaryAndReleaseValues!(_);
	
	private static Dictionary<UUID, ScriptInstance> _entityScriptInstances = new .() ~ {
		for (var entry in _)
		{
			entry.value?.ReleaseRef();
		}
		delete _;
	}
	
	public static Dictionary<StringView, ScriptClass> EntityClasses => _entityScripts;

	public static Scene Context => s_Context;

	private static Dictionary<UUID, ScriptFieldMap> _entityFields = new .() ~
		{
			for (var value in _entityFields.Values)
			{
				DeleteDictionaryAndKeys!(value);
			}

			delete _;
		};

	internal static class Attributes
	{
		internal static MonoClass* s_ShowInEditorAttribute;
	}
	
	public static void Init()
	{
		Mono.mono_set_assemblies_path("mono/lib");

		s_RootDomain = Mono.mono_jit_init("GlitchyEngineJITRuntime");
		Log.EngineLogger.Assert(s_RootDomain != null, "Failed to initialize mono root domain");
		
		ScriptGlue.Init();

		LoadScriptAssemblies();
	}

	static void LoadScriptAssemblies()
	{
		CreateAppDomain("GlitchyEngineScriptRuntime");
		(s_CoreAssembly, s_CoreAssemblyImage) = LoadAssembly("resources/scripts/ScriptCore.dll");
		(s_AppAssembly, s_AppAssemblyImage) = LoadAssembly("SandboxProject/Assets/Scripts/bin/Sandbox.dll");

		GetEntitiesFromAssemblies();

		ScriptGlue.RegisterManagedComponents();
	}

	public static void SetContext(Scene scene)
	{
		SetReference!(s_Context, scene);
	}

	public static void OnRuntimeStop()
	{
		for (var entry in _entityScriptInstances)
		{
			entry.value.ReleaseRef();
		}
		_entityScriptInstances.Clear();

		SetContext(null);
	}

	public static bool InitializeInstance(Entity entity, ScriptComponent* script)
	{
		ScriptClass scriptClass = GetScriptClass(script.ScriptClassName);

		if (scriptClass == null)
			return false;

		script.Instance = new ScriptInstance(scriptClass);
		script.Instance..ReleaseRef();

		_entityScriptInstances[entity.UUID] = script.Instance..AddRef();

		script.Instance.Instantiate(entity.UUID);

		CopyEditorFieldsToInstance(entity, script);

		return true;
	}

	private static void CopyEditorFieldsToInstance(Entity entity, ScriptComponent* script)
	{
		// Technically the map is for a different entity (namely the editor-entity),
		// however the UUID is the same, so we get the correct field map
		let fields = GetScriptFieldMap(entity);

		for (var (fieldName, field) in fields)
		{
			// TODO: a litte assertion maybe?

			ScriptField scriptField = script.Instance.ScriptClass.Fields[fieldName];

			script.Instance.SetFieldValue(scriptField, field._data);
		}
	}

	private static MonoAssembly* LoadCSharpAssembly(StringView assemblyPath)
	{
		List<uint8> data = new List<uint8>(1024);

		File.ReadAll(assemblyPath, data);
	
	    // NOTE: We can't use this image for anything other than loading the assembly because this image doesn't have a reference to the assembly
	    MonoImageOpenStatus status = .ImageInvalid;
	    MonoImage* image = Mono.mono_image_open_from_data_full(data.Ptr, (.)data.Count, true, &status, false);

		delete data;

	    if (status != .Ok)
	    {
	        char8* errorMessage = Mono.mono_image_strerror(status);

			Log.EngineLogger.Error($"Failed to load C# Assembly: \"{StringView(errorMessage)}\"");

	        return null;
	    }
	
	    MonoAssembly* assembly = Mono.mono_assembly_load_from_full(image, assemblyPath.ToScopeCStr!(), &status, 0);
	    Mono.mono_image_close(image);

	    return assembly;
	}

	static void CreateAppDomain(StringView name)
	{
		s_AppDomain = Mono.mono_domain_create_appdomain(name.ToScopeCStr!(), null);
		Mono.mono_domain_set(s_AppDomain, true);
	}

	static (MonoAssembly* assembly, MonoImage* image) LoadAssembly(StringView filepath)
	{
		MonoAssembly* assembly = LoadCSharpAssembly(filepath);
		MonoImage* image = Mono.mono_assembly_get_image(assembly);

		return (assembly, image);
	}

	private static void GetEntitiesFromAssemblies()
	{
		for (var entry in _entityScripts)
		{
			entry.value.ReleaseRef();
		}
		_entityScripts.Clear();

		for (var sharpClass in _sharpClasses)
		{
			sharpClass.value.ReleaseRef();
		}
		_sharpClasses.Clear();
		
		if (s_EngineObject != null)
		{
			s_EngineObject.ReleaseRef();
			s_EntityRoot.ReleaseRef();
		}

		s_EngineObject = new ScriptClass("GlitchyEngine.Core", "EngineObject", s_CoreAssemblyImage);
		s_EntityRoot = new ScriptClass("GlitchyEngine", "Entity", s_CoreAssemblyImage);

		Log.EngineLogger.Assert(s_EntityRoot != null);

		Attributes.s_ShowInEditorAttribute = Mono.mono_class_from_name(s_CoreAssemblyImage, "GlitchyEngine.Editor", "ShowInEditorAttribute");

	    MonoTableInfo* typeDefinitionsTable = Mono.mono_image_get_table_info(s_AppAssemblyImage, .MONO_TABLE_TYPEDEF);
	    int32 numTypes = Mono.mono_table_info_get_rows(typeDefinitionsTable);

	    for (int32 i = 0; i < numTypes; i++)
	    {
	        int32[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_SIZE] cols = .();
	        Mono.mono_metadata_decode_row(typeDefinitionsTable, i, (.)&cols, (.)SOME_RANDOM_ENUM.MONO_TYPEDEF_SIZE);

	        char8* nameSpace = Mono.mono_metadata_string_heap(s_AppAssemblyImage, (.)cols[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_NAMESPACE]);
			char8* name = Mono.mono_metadata_string_heap(s_AppAssemblyImage, (.)cols[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_NAME]);
			
			MonoClass* monoClass = Mono.mono_class_from_name(s_AppAssemblyImage, nameSpace, name);

			if (monoClass != null && Mono.mono_class_is_subclass_of(monoClass, s_EntityRoot.[Friend]_monoClass, false))
			{
				ScriptClass entityScript = new ScriptClass(StringView(nameSpace), StringView(name), s_AppAssemblyImage);
				_entityScripts.Add(entityScript.FullName, entityScript);

				Log.EngineLogger.Info($"Added entity \"{entityScript.FullName}\"");
			}
	    }
	}

	public static void ReloadAssemblies()
	{
		Mono.mono_domain_set(s_RootDomain, false);

		Mono.mono_domain_unload(s_AppDomain);

		LoadScriptAssemblies();

		// TODO: ScriptFields might get added
		// TODO: ScriptField Types may change after reload!
		// TODO: Scripts may be renamed (probably not detectable (trivially))

		// TODO: Reload in play mode
		// Only scripts that were changed should actually be reinstatiated
	}

	public static void Shutdown()
	{
		Mono.mono_domain_set(s_RootDomain, false);

		Mono.mono_domain_unload(s_AppDomain);
		s_AppDomain = null;

		Mono.mono_jit_cleanup(s_RootDomain);
		s_RootDomain = null;
	}

	internal static void RegisterSharpType(SharpType sharpType)
	{
		_sharpClasses.Add(sharpType.FullName, sharpType..AddRef());
	}

	internal static SharpType GetSharpType(MonoType* monoType)
	{
		StringView typeName = StringView(Mono.mono_type_get_name(monoType));

		if (_sharpClasses.TryGetValue(typeName, let sharpType))
			return sharpType..AddRef();

		Mono.MonoTypeEnum fieldType = Mono.Mono.mono_type_get_type(monoType);

		MonoClass* monoClass = Mono.mono_type_get_class(monoType);

		if (monoClass == null)
			return null;

		StringView className = StringView(Mono.mono_class_get_name(monoClass));
		StringView classNamespace = StringView(Mono.mono_class_get_namespace(monoClass));

		// TODO: at the moment only allow user-structs
		if (classNamespace.StartsWith("GlitchyEngine"))
			return null;

		switch (fieldType)
		{
		case .Class, .Valuetype, .Enum:
			ScriptFieldType scriptType = .None;

			if (fieldType == .Class)
				scriptType = .Class;
			else if (fieldType == .Enum)
				scriptType = .Enum;
			else if (fieldType == .Valuetype)
				scriptType = .Struct;

			Log.EngineLogger.AssertDebug(scriptType != .None);

			return new SharpClass(classNamespace, className, Mono.mono_class_get_image(monoClass), scriptType);
		default:
			return null;
		}
	}

	public static void CreateScriptFieldMap(Entity entity)
	{
		Log.EngineLogger.AssertDebug(entity.IsValid);

		if (_entityFields.TryGetValue(entity.UUID, var entityFields))
		{
			ClearDictionaryAndDeleteKeys!(entityFields);
		}
		else
		{
			entityFields = new ScriptFieldMap();
			_entityFields.Add(entity.UUID, entityFields);
		}

		let scriptComponent = entity.GetComponent<ScriptComponent>();

		ScriptClass scriptClass = GetScriptClass(scriptComponent.ScriptClassName);
		
		Log.EngineLogger.AssertDebug(scriptClass != null);

		for (let (fieldName, field) in scriptClass.Fields)
		{
			entityFields.Add(new String(fieldName), ScriptFieldInstance(field.FieldType));
		}
	}

	public static ScriptFieldMap GetScriptFieldMap(Entity entity)
	{
		Log.EngineLogger.AssertDebug(entity.IsValid);

		let uuid = entity.UUID;

		// TODO: Entites bekommen noch kein Eintrag hier!!
		Log.EngineLogger.AssertDebug(_entityFields.ContainsKey(uuid));

		return _entityFields[uuid];
	}

	public static MonoObject* GetManagedInstance(UUID entityId)
	{
		if (_entityScriptInstances.TryGetValue(entityId, let scriptInstance))
			return scriptInstance.MonoInstance;
		
		return null;
	}

	public static ScriptClass GetScriptClass(StringView name)
	{
		EntityClasses.TryGetValue(name, let scriptClass);

		return scriptClass;
	}












	/*static void Samples()
	{
		PrintAssemblyTypes(s_CoreAssembly);

		function MonoString*() v = => Sample;

		Mono.mono_add_internal_call("GlitchyEngine.CSharpTesting::Sample", v);

		function void(in float3, in float3, out float3) v2 = => Add;

		Mono.mono_add_internal_call("GlitchyEngine.float3::Add_Internal", v2);

		// Create object
		ScriptClass myClass = scope .("GlitchyEngine", "CSharpTesting");
		MonoObject* instance = myClass.CreateInstance();

		MonoMethod* simpleMethod = myClass.GetMethod("PrintFloatVar");
		myClass.Invoke(simpleMethod, instance);

		MonoMethod* methodWithArg = myClass.GetMethod("IncrementFloatVar", 1);

		float increment = 2.0f;
		float returnedValue = myClass.Invoke<float>(methodWithArg, instance, &increment);

		Log.EngineLogger.Info($"C# returned: {returnedValue}");

		Mono.mono_runtime_invoke(simpleMethod, instance, null, null);
	}

	[LinkName(.C), AlwaysInclude, Export]
	public static void DoSomething()
	{
		Console.WriteLine("P/Invoke: Hallo von der Engine!");
	}

	[LinkName(.C), AlwaysInclude, Export]
	public static void Add(in float3 a, in float3 b, out float3 c)
	{
		c = a + b;
	}
	
	[LinkName(.C), AlwaysInclude]
	public static MonoString* Sample()
	{
	  return Mono.mono_string_new(Mono.mono_domain_get(), "Hello!");
	}

	private static void PrintAssemblyTypes(MonoAssembly* assembly)
	{
	    MonoImage* image = Mono.mono_assembly_get_image(assembly);
	    MonoTableInfo* typeDefinitionsTable = Mono.mono_image_get_table_info(image, .MONO_TABLE_TYPEDEF);
	    int32 numTypes = Mono.mono_table_info_get_rows(typeDefinitionsTable);

	    for (int32 i = 0; i < numTypes; i++)
	    {
	        int32[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_SIZE] cols = .();
	        Mono.mono_metadata_decode_row(typeDefinitionsTable, i, (.)&cols, (.)SOME_RANDOM_ENUM.MONO_TYPEDEF_SIZE);

	        char8* nameSpace = Mono.mono_metadata_string_heap(image, (.)cols[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_NAMESPACE]);
	        char8* name = Mono.mono_metadata_string_heap(image, (.)cols[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_NAME]);

			Log.EngineLogger.Info($"{StringView(nameSpace)}.{StringView(name)}");
	    }
	}*/
}
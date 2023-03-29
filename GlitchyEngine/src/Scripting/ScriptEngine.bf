using Mono;
using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Math;
using GlitchyEngine.World;
using GlitchyEngine.Core;

namespace GlitchyEngine.Scripting;

static class ScriptEngine
{
	private static MonoDomain* s_RootDomain;
	private static MonoDomain* s_AppDomain;

	private static MonoAssembly* s_CoreAssembly;
	private static MonoImage* s_CoreAssemblyImage;

	private static Scene s_Context ~ _?.ReleaseRef();

	private static ScriptClass s_EntityRoot ~ delete _;
	private static ScriptClass s_EngineObject ~ delete _;

	private static Dictionary<StringView, ScriptClass> _entityScripts = new .() ~ {
		for (var entry in _)
		{
			delete entry.value;
		}
		delete _entityScripts;
	};

	private static Dictionary<UUID, ScriptInstance> _entityScriptInstances = new .() ~ {
		for (var entry in _)
		{
			entry.value?.ReleaseRef();
		}
		delete _;
	};

	public static Dictionary<StringView, ScriptClass> EntityClasses => _entityScripts;

	public static Scene Context => s_Context;

	public static void Init()
	{
		Mono.mono_set_assemblies_path("mono/lib");

		s_RootDomain = Mono.mono_jit_init("GlitchyEngineJITRuntime");
		Log.EngineLogger.Assert(s_RootDomain != null, "Failed to initialize mono root domain");
		
		ScriptGlue.Init();

		LoadAssembly("resources/scripts/ScriptCore.dll");

		ScriptGlue.RegisterManagedComponents();

		//Samples();
	}

	public static void SetContext(Scene scene)
	{
		SetReference!(s_Context, scene);
	}

	public static void InitializeInstance(Entity entity, ScriptComponent* script)
	{
		_entityScriptInstances[entity.UUID] = script.Instance..AddRef();

		script.Instance.Instantiate(entity.UUID);
		script.Instance.InvokeOnCreate();
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

	static void LoadAssembly(StringView filepath)
	{
		s_AppDomain = Mono.mono_domain_create_appdomain("GlitchyEngineScriptRuntime", null);
		Mono.mono_domain_set(s_AppDomain, true);

		s_CoreAssembly = LoadCSharpAssembly(filepath);
		s_CoreAssemblyImage = Mono.mono_assembly_get_image(s_CoreAssembly);
		GetEntitiesFromAssembly(s_CoreAssembly);
	}

	private static void GetEntitiesFromAssembly(MonoAssembly* assembly)
	{
		for (var entry in _entityScripts)
		{
			delete entry.value;
		}
		_entityScripts.Clear();

	    MonoImage* image = Mono.mono_assembly_get_image(assembly);
	    MonoTableInfo* typeDefinitionsTable = Mono.mono_image_get_table_info(image, .MONO_TABLE_TYPEDEF);
	    int32 numTypes = Mono.mono_table_info_get_rows(typeDefinitionsTable);

		s_EngineObject = new ScriptClass("GlitchyEngine.Core", "EngineObject");
		s_EntityRoot = new ScriptClass("GlitchyEngine", "Entity");

		Log.EngineLogger.Assert(s_EntityRoot != null);

	    for (int32 i = 0; i < numTypes; i++)
	    {
	        int32[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_SIZE] cols = .();
	        Mono.mono_metadata_decode_row(typeDefinitionsTable, i, (.)&cols, (.)SOME_RANDOM_ENUM.MONO_TYPEDEF_SIZE);

	        char8* nameSpace = Mono.mono_metadata_string_heap(image, (.)cols[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_NAMESPACE]);
	        char8* name = Mono.mono_metadata_string_heap(image, (.)cols[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_NAME]);

			MonoClass* monoClass = Mono.mono_class_from_name(image, nameSpace, name);

			if (monoClass != null && Mono.mono_class_is_subclass_of(monoClass, s_EntityRoot.[Friend]_monoClass, false))
			{
				ScriptClass entityScript = new ScriptClass(StringView(nameSpace), StringView(name));
				_entityScripts.Add(entityScript.FullName, entityScript);

				Log.EngineLogger.Info($"Added entity \"{entityScript.FullName}\"");
			}
	    }
	}

	public static void Shutdown()
	{
		/*Mono.mono_assembly_close(s_CoreAssembly);
		s_CoreAssembly = null;
		
		Mono.mono_domain_unload(s_AppDomain);
		s_AppDomain = null;*/

		Mono.mono_jit_cleanup(s_RootDomain);
		s_RootDomain = null;
	}


















	/*static void Samples()
	{
		PrintAssemblyTypes(s_CoreAssembly);

		function MonoString*() v = => Sample;

		Mono.mono_add_internal_call("GlitchyEngine.CSharpTesting::Sample", v);

		function void(in Vector3, in Vector3, out Vector3) v2 = => Add;

		Mono.mono_add_internal_call("GlitchyEngine.Vector3::Add_Internal", v2);

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
	public static void Add(in Vector3 a, in Vector3 b, out Vector3 c)
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
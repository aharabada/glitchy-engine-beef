using Mono;
using System;
using System.IO;
using System.Collections;
namespace GlitchyEngine.Scripting;

static class ScriptEngine
{
	private static MonoDomain* s_RootDomain;
	private static MonoDomain* s_AppDomain;

	private static MonoAssembly* s_CoreAssembly;

	public static void Init()
	{
		Mono.mono_set_assemblies_path("mono/lib");

		s_RootDomain = Mono.mono_jit_init("GlitchyEngineJITRuntime");

		Log.EngineLogger.Assert(s_RootDomain != null, "Failed to initialize mono root domain");
		
		// Create an App Domain
		s_AppDomain = Mono.mono_domain_create_appdomain("GlitchyEngineScriptRuntime", null);
		Mono.mono_domain_set(s_AppDomain, true);

		s_CoreAssembly = LoadCSharpAssembly("resources/scripts/ScriptCore.dll");
		PrintAssemblyTypes(s_CoreAssembly);

		function MonoString*() v = => Sample;

		Mono.mono_add_internal_call("GlitchyEngine.CSharpTesting::Sample", v);

		// Create object
		MonoImage* image = Mono.mono_assembly_get_image(s_CoreAssembly);

		MonoClass* monoClass = Mono.mono_class_from_name(image, "GlitchyEngine", "CSharpTesting");
		
		MonoObject* instance = Mono.mono_object_new(s_AppDomain, monoClass);
		Mono.mono_runtime_object_init(instance);

		MonoMethod* simpleMethod = Mono.mono_class_get_method_from_name(monoClass, "PrintFloatVar", 0);
		Mono.mono_runtime_invoke(simpleMethod, instance, null, null);

		MonoMethod* methodWithArg = Mono.mono_class_get_method_from_name(monoClass, "IncrementFloatVar", 1);

		float increment = 2.0f;
		void*[1] args = .(&increment);

		MonoObject* returnValue = Mono.mono_runtime_invoke(methodWithArg, instance, &args, null);

		float returnedValue = *(float*)Mono.mono_object_unbox(returnValue);

		Log.EngineLogger.Info($"C# returned: {returnedValue}");

		Mono.mono_runtime_invoke(simpleMethod, instance, null, null);
	}

	[LinkName(.C), AlwaysInclude, Export]
	public static void DoSomething()
	{
		Console.WriteLine("P/Invoke: Hallo von der Engine!");
	}
	
	[LinkName(.C), AlwaysInclude]
	public static MonoString* Sample()
	{
	  return Mono.mono_string_new(Mono.mono_domain_get(), "Hello!");
	}

	private static MonoAssembly* LoadCSharpAssembly(StringView assemblyPath)
	{
		List<uint8> data = new:ScopedAlloc! List<uint8>(1024);

		File.ReadAll(assemblyPath, data);
	
	    // NOTE: We can't use this image for anything other than loading the assembly because this image doesn't have a reference to the assembly
	    MonoImageOpenStatus status = .ImageInvalid;
	    MonoImage* image = Mono.mono_image_open_from_data_full(data.Ptr, (.)data.Count, true, &status, false);
	
	    if (status != .Ok)
	    {
	        char8* errorMessage = Mono.mono_image_strerror(status);

			Log.EngineLogger.Error($"Failed to load C# Assembly: \"{StringView(errorMessage)}\"");

	        return null;
	    }
	
	    MonoAssembly* assembly = Mono.mono_assembly_load_from_full(image, assemblyPath.ToScopeCStr!(), &status, 0);
	    Mono.mono_image_close(image);

		// Create object

		// call simple method

		// call method with args
	
	    return assembly;
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
}
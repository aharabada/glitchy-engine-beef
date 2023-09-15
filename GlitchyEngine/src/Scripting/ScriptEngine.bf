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
		("GlitchyEngine.Math.float2", .float2),
		("GlitchyEngine.Math.float3", .float3),
		("GlitchyEngine.Math.float4", .float4),

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

	private static ScriptClass s_ComponentRoot ~ _?.ReleaseRef();
	private static ScriptClass s_EntityRoot ~ _?.ReleaseRef();
	private static ScriptClass s_EngineObject ~ _?.ReleaseRef();

	private static Dictionary<StringView, SharpType> _sharpClasses = new .() ~ DeleteDictionaryAndReleaseValues!(_);
	
	private static Dictionary<StringView, ScriptClass> _entityScripts = new .() ~ DeleteDictionaryAndReleaseValues!(_);
	private static Dictionary<StringView, ScriptClass> _componentClasses = new .() ~ DeleteDictionaryAndReleaseValues!(_);
	
	private static Dictionary<UUID, ScriptInstance> _entityScriptInstances = new .() ~ {
		for (var entry in _)
		{
			entry.value?.ReleaseRef();
		}
		delete _;
	}

	public static Dictionary<StringView, ScriptClass> EntityClasses => _entityScripts;
	public static Dictionary<StringView, ScriptClass> ComponentClasses => _componentClasses;

	public static Scene Context => s_Context;

	private static Dictionary<UUID, ScriptFieldMap> _entityFields = new .() ~
		{
			for (var value in _entityFields.Values)
			{
				DeleteDictionaryAndKeys!(value);
			}

			delete _;
		};
	
	private static FileSystemWatcher _userAssemblyWatcher ~ delete _;

	// TODO: This should be a global setting somewhere
	private static bool _debuggingEnabled = true;

	private static String _appAssemblyPath = new .() ~ delete _;

	internal static class Attributes
	{
		internal static MonoClass* s_ShowInEditorAttribute;
	}
	
	public static void Init()
	{
		InitMono();
		ScriptGlue.Init();

		LoadScriptAssemblies();
	}

	/// Changes the path to the current app assembly.
	public static void SetAppAssemblyPath(StringView appAssemblyPath)
	{
		_appAssemblyPath.Set(appAssemblyPath);

		ReloadAssemblies();
	}

	static void InitMono()
	{
		Mono.mono_set_assemblies_path("mono/lib");

		if (_debuggingEnabled)
		{
			char8*[2] options = .(
				  "--debugger-agent=transport=dt_socket,address=127.0.0.1:2550,server=y,suspend=n,loglevel=3,logfile=MonoDebugger.log",
				  "--soft-breakpoints"
				);

			Mono.mono_jit_parse_options(options.Count, &options);
			Mono.mono_debug_init(.Mono);
		}

		s_RootDomain = Mono.mono_jit_init("GlitchyEngineJITRuntime");
		Log.EngineLogger.Assert(s_RootDomain != null, "Failed to initialize mono root domain");

		if (_debuggingEnabled)
		{
			Mono.mono_debug_domain_create(s_RootDomain);
		}

		Mono.mono_thread_set_main(Mono.mono_thread_current());
	}

	static void InitAssemblyWatcher()
	{
		// We don't need a file system watcher, if we have nothing to watch...
		if (!File.Exists(_appAssemblyPath))
			return;

		String directory = scope .();
		Path.GetDirectoryPath(_appAssemblyPath, directory);

		if (_userAssemblyWatcher != null) // _userAssemblyWatcher.Directory != directory
		{
			delete _userAssemblyWatcher;
		}

		String fileName = scope .("*/");
		Path.GetFileName(_appAssemblyPath, fileName);

		// TODO: Obviously don't hardcode path
		_userAssemblyWatcher = new FileSystemWatcher(directory, fileName);
		_userAssemblyWatcher.OnChanged.Add(new (fileName) =>
		{
			// TODO: Temporary, we want to be able to reload while in play-mode. (+ Editor Scripts will be a thing some day)
			if (_entityScriptInstances.Count > 0)
			{
				Log.EngineLogger.Warning("There are script instances. Skipping assembly reload.");
				return;
			}

			Log.EngineLogger.Info("Script reload requested.");
			_userAssemblyWatcher.StopRaisingEvents();

			Application.Instance.InvokeOnMainThread(new () =>
			{
				Log.EngineLogger.Info("Reloading scripts...");
				ReloadAssemblies();
				Log.EngineLogger.Info("Scripts reloaded!");

				_userAssemblyWatcher.StartRaisingEvents();
			});

		});

		_userAssemblyWatcher.StartRaisingEvents();
	}

	/// Gets rid of all entity fields.
	public static void ClearEntityScriptFields()
	{
		for (var value in _entityFields.Values)
		{
			DeleteDictionaryAndKeys!(value);
		}

		_entityFields.Clear();
	}

	static void LoadScriptAssemblies()
	{
		CreateAppDomain("GlitchyEngineScriptRuntime");
		(s_CoreAssembly, s_CoreAssemblyImage) = LoadAssembly("resources/scripts/ScriptCore.dll", _debuggingEnabled);

		if (File.Exists(_appAssemblyPath))
			(s_AppAssembly, s_AppAssemblyImage) = LoadAssembly(_appAssemblyPath, _debuggingEnabled);
		else
		{
			s_AppAssembly = null;
			s_AppAssemblyImage = null;
		}

		GetCoreAttributes();
		GetCoreClasses();

		ClearDictionaryAndReleaseValues!(_sharpClasses);
		ClearDictionaryAndReleaseValues!(_componentClasses);
		ClearDictionaryAndReleaseValues!(_entityScripts);
		
		GetComponentsFromAssemblies();

		GetEntitiesFromAssemblies();

		ScriptGlue.RegisterManagedComponents();

		InitAssemblyWatcher();
	}

	public static void SetContext(Scene scene)
	{
		SetReference!(s_Context, scene);
	}

	public static void OnRuntimeStop()
	{
		for (var entry in _entityScriptInstances)
		{
			entry.value?.ReleaseRef();
		}
		_entityScriptInstances.Clear();

		SetContext(null);
	}

	public static bool InitializeInstance(Entity entity, ScriptComponent* script)
	{
		ScriptClass scriptClass = GetScriptClass(script.ScriptClassName);

		if (scriptClass == null)
			return false;

		UUID entityId = entity.UUID;

		script.Instance = new ScriptInstance(entityId, scriptClass);
		script.Instance..ReleaseRef();

		if (_entityScriptInstances.TryGetValue(entityId, let currentInstance))
			currentInstance.ReleaseRef();

		_entityScriptInstances[entityId] = script.Instance..AddRef();

		script.Instance.Instantiate(entityId);

		return true;
	}

	public static void DestroyInstance(Entity entity, ScriptComponent* script)
	{
		UUID entityId = entity.UUID;

		if (script.Instance != null)
			script.Instance = null;

		script.ScriptClassName = null;

		if (_entityScriptInstances.TryGetValue(entityId, let currentInstance))
			currentInstance.ReleaseRef();

		_entityScriptInstances[entityId] = null;
	}

	public static void CopyEditorFieldsToInstance(Entity entity, ScriptComponent* script)
	{
		Log.EngineLogger.AssertDebug(script.Instance != null);

		// Technically the map is for a different entity (namely the editor-entity),
		// however the UUID is the same, so we get the correct field map
		let fields = GetScriptFieldMap(entity);

		for (var (fieldName, field) in fields)
		{
			// TODO: a litte assertion maybe?
			
			ScriptField scriptField = script.Instance.ScriptClass.Fields[fieldName];

			switch (scriptField.FieldType)
			{
			case .Entity:
				// On the C# side we actually differentiate between an Entity and the Script
				// in the sense that getting an entity and a script yields two different results (one creates a new Entity-Class instance, the other returns the actual instance).
				// But here its just easier to always use the script instance.
				// Obviously breaks once we support multiple scripts per entity.
				UUID referencedId = field.GetData<UUID>();
				MonoObject* referencedEntity = GetManagedInstance(referencedId);
				script.Instance.SetFieldValue(scriptField, referencedEntity);
			case .Component:
				// We create a new instance of a component class
				MonoType* type = scriptField.GetMonoType();
				
				SharpType sharpType = ScriptEngine.GetSharpType(type);

				var componentClass = ComponentClasses[sharpType.FullName];

				MonoObject* componentInstance = script.Instance.CreateComponentInstance(componentClass);
				script.Instance.SetFieldValue(scriptField, componentInstance);

				sharpType.ReleaseRef();
			default:
				script.Instance.SetFieldValue(scriptField, field._data);
			}
		}
	}

	private static MonoAssembly* LoadCSharpAssembly(StringView assemblyPath, bool loadPDB = false)
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

		if (loadPDB)
		{
			String pdbPath = scope .();
			Path.ChangeExtension(assemblyPath, ".pdb", pdbPath);

			if (File.Exists(pdbPath))
			{
				Log.EngineLogger.Trace($"Loading PDB \"{pdbPath}\"...");

				List<uint8> pdbData = new List<uint8>(1024);

				let result = File.ReadAll(pdbPath, pdbData);

				if (result case .Err(let error))
				{
					Log.EngineLogger.Error("Failed to load PDB file ({error}).");
				}

				Mono.mono_debug_open_image_from_memory(image, pdbData.Ptr, (int32)pdbData.Count);

				delete pdbData;
			}
			else
			{
				Log.EngineLogger.Warning($"Debugging enabled but no PDB-File found \"{assemblyPath}\".");
			}
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

	static (MonoAssembly* assembly, MonoImage* image) LoadAssembly(StringView filepath, bool loadPDB = false)
	{
		MonoAssembly* assembly = LoadCSharpAssembly(filepath, loadPDB);
		MonoImage* image = Mono.mono_assembly_get_image(assembly);

		return (assembly, image);
	}

	/// Retrieves the base classes from which every Component or Entity inherits
	static void GetCoreClasses()
	{
		ReleaseRefAndNullify!(s_EngineObject);
		ReleaseRefAndNullify!(s_EntityRoot);
		ReleaseRefAndNullify!(s_ComponentRoot);

		s_EngineObject = new ScriptClass("GlitchyEngine.Core", "EngineObject", s_CoreAssemblyImage, .Class);
		s_EntityRoot = new ScriptClass("GlitchyEngine", "Entity", s_CoreAssemblyImage, .Entity);
		s_ComponentRoot = new ScriptClass("GlitchyEngine", "Component", s_CoreAssemblyImage, .Component);
	}
	
	/// Retrieves the classes for Attributes that are defined in the Core library
	static void GetCoreAttributes()
	{
		Attributes.s_ShowInEditorAttribute = Mono.mono_class_from_name(s_CoreAssemblyImage, "GlitchyEngine.Editor", "ShowInEditorAttribute");
	}

	private static void GetEntitiesFromAssemblies()
	{
		if (s_AppAssemblyImage == null)
			return;

	    MonoTableInfo* typeDefinitionsTable = Mono.mono_image_get_table_info(s_AppAssemblyImage, .MONO_TABLE_TYPEDEF);
	    int32 numTypes = Mono.mono_table_info_get_rows(typeDefinitionsTable);

	    for (int32 i = 0; i < numTypes; i++)
	    {
	        int32[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_SIZE] cols = .();
	        Mono.mono_metadata_decode_row(typeDefinitionsTable, i, (.)&cols, (.)SOME_RANDOM_ENUM.MONO_TYPEDEF_SIZE);

	        char8* nameSpace = Mono.mono_metadata_string_heap(s_AppAssemblyImage, (.)cols[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_NAMESPACE]);
			char8* name = Mono.mono_metadata_string_heap(s_AppAssemblyImage, (.)cols[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_NAME]);
			
			MonoClass* monoClass = Mono.mono_class_from_name(s_AppAssemblyImage, nameSpace, name);
			
			// Check if it is an entity
			if (monoClass != null && Mono.mono_class_is_subclass_of(monoClass, s_EntityRoot.[Friend]_monoClass, false))
			{
				ScriptClass entityScript = new ScriptClass(StringView(nameSpace), StringView(name), s_AppAssemblyImage, .Entity);
				_entityScripts.Add(entityScript.FullName, entityScript);

				Log.EngineLogger.Info($"Added entity \"{entityScript.FullName}\"");
			}
	    }
	}
	private static void GetComponentsFromAssemblies()
	{
	    MonoTableInfo* typeDefinitionsTable = Mono.mono_image_get_table_info(s_CoreAssemblyImage, .MONO_TABLE_TYPEDEF);
	    int32 numTypes = Mono.mono_table_info_get_rows(typeDefinitionsTable);

	    for (int32 i = 0; i < numTypes; i++)
	    {
	        int32[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_SIZE] cols = .();
	        Mono.mono_metadata_decode_row(typeDefinitionsTable, i, (.)&cols, (.)SOME_RANDOM_ENUM.MONO_TYPEDEF_SIZE);

	        char8* nameSpace = Mono.mono_metadata_string_heap(s_CoreAssemblyImage, (.)cols[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_NAMESPACE]);
			char8* name = Mono.mono_metadata_string_heap(s_CoreAssemblyImage, (.)cols[(.)SOME_RANDOM_ENUM.MONO_TYPEDEF_NAME]);
			
			MonoClass* monoClass = Mono.mono_class_from_name(s_CoreAssemblyImage, nameSpace, name);
			
			// Check if it is a component but not the root Component class
			if (monoClass != null && monoClass != s_ComponentRoot.[Friend]_monoClass && Mono.mono_class_is_subclass_of(monoClass, s_ComponentRoot.[Friend]_monoClass, false))
			{
				ScriptClass componentClass = new ScriptClass(StringView(nameSpace), StringView(name), s_CoreAssemblyImage, .Component);
				_componentClasses.Add(componentClass.FullName, componentClass);

				Log.EngineLogger.Info($"Added component \"{componentClass.FullName}\"");
			}
	    }
	}

	public static void ReloadAssemblies()
	{
		Debug.Profiler.ProfileFunction!();

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
		//if (classNamespace.StartsWith("GlitchyEngine"))
		//	return null;
		
		ScriptFieldType scriptType = .None;

		if (Mono.mono_class_is_enum(monoClass))
		{
			scriptType = .Enum;

			return new SharpEnum(classNamespace, className, Mono.mono_class_get_image(monoClass));
		}
		else if (fieldType == .Class)
		{
			if (Mono.mono_class_is_subclass_of(monoClass, s_EntityRoot._monoClass, false))
			{
				scriptType = .Entity;
			}
			else if (Mono.mono_class_is_subclass_of(monoClass, s_ComponentRoot._monoClass, false))
			{
				scriptType = .Component;
			}
			else
			{
				scriptType = .Class;
			}
		}
		else if (fieldType == .Valuetype)
		{
			scriptType = .Struct;
		}

		Log.EngineLogger.AssertDebug(scriptType != .None);

		return new SharpClass(classNamespace, className, Mono.mono_class_get_image(monoClass), scriptType);
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

		void AddFieldsToMap(Dictionary<StringView, ScriptField> classFields, StringView baseName)
		{
			for (let (fieldName, field) in classFields)
			{
				/*if (field.FieldType == .Struct && field.SharpType != null)
				{
					AddFieldsToMap(field.SharpType.Fields, scope $"{baseName}{fieldName}.");
				}
				else
				{
					entityFields.Add(new $"{baseName}{fieldName}", ScriptFieldInstance(field.FieldType));
				}*/

				entityFields.Add(new String(fieldName), ScriptFieldInstance(field.FieldType));
			}
		}

		AddFieldsToMap(scriptClass.Fields, "");
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

	internal static void HandleMonoException(MonoException* exception, ScriptInstance sourceInstance = null)
	{
		MonoExceptionHelper wrappedException = new MonoExceptionHelper(exception);

		String entityInfo = scope .();

		if (sourceInstance != null)
		{
			wrappedException.Instance = sourceInstance.EntityId;

			Result<Entity> sourceEntity = Context.GetEntityByID(sourceInstance.EntityId);

			if (sourceEntity case .Ok(let e))
			{
				entityInfo.AppendF($" ({e.Name} | {sourceInstance.EntityId})");
			}
		}

		Log.ClientLogger.Error($"Mono Exception \"{wrappedException.FullName}\": \"{wrappedException.Message}\"{entityInfo}\nStackTrace:\n{wrappedException.StackTrace}", wrappedException);

		wrappedException.ReleaseRef();
	}
}

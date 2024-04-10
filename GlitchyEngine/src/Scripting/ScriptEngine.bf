using Mono;
using System;
using System.IO;
using System.Collections;
using GlitchyEngine.Core;
using GlitchyEngine.Math;
using GlitchyEngine.Serialization;
using GlitchyEngine.World;
using System.Diagnostics;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

class EngineClasses
{
	// TODO: Not all of there are actually ScriptClasses (actually none of them are...)

	private ScriptClass s_ComponentRoot ~ _?.ReleaseRef();
	private ScriptClass s_EntityRoot ~ _?.ReleaseRef();
	private ScriptClass s_EngineObject ~ _?.ReleaseRef();

	private EntityEditorWrapper s_EntityEditor ~ _?.ReleaseRef();

	private ScriptClass s_EntitySerializer ~ _?.ReleaseRef();
	private ScriptClass s_SerializationContext ~ _?.ReleaseRef();

	private ScriptClass s_Collision2D ~ _?.ReleaseRef();

	private ScriptClass s_RunInEditModeAttribute ~ _?.ReleaseRef();

	public ScriptClass ComponentRoot => s_ComponentRoot;
	public ScriptClass EntityRoot => s_EntityRoot;
	public ScriptClass EngineObject => s_EngineObject;

	public EntityEditorWrapper EntityEditor => s_EntityEditor;

	public ScriptClass EntitySerializer => s_EntitySerializer;

	public ScriptClass Collision2D => s_Collision2D;

	public ScriptClass RunInEditModeAttribute => s_RunInEditModeAttribute;

	internal void ReleaseAndNullify()
	{
		ReleaseRefAndNullify!(s_EngineObject);
		ReleaseRefAndNullify!(s_EntityRoot);
		ReleaseRefAndNullify!(s_ComponentRoot);

		ReleaseRefAndNullify!(s_EntityEditor);

		ReleaseRefAndNullify!(s_EntitySerializer);
		ReleaseRefAndNullify!(s_SerializationContext);

		ReleaseRefAndNullify!(s_Collision2D);

		ReleaseRefAndNullify!(s_RunInEditModeAttribute);
	}

	internal void LoadClasses(MonoImage* image)
	{
		ReleaseAndNullify();

		s_EngineObject = new ScriptClass("GlitchyEngine.Core", "EngineObject", image);
		s_EntityRoot = new ScriptClass("GlitchyEngine", "Entity", image);
		s_ComponentRoot = new ScriptClass("GlitchyEngine.Core", "Component", image);

		// Editor classes
		s_EntityEditor = new EntityEditorWrapper("GlitchyEngine.Editor", "EntityEditor", image);

		s_EntitySerializer = new ScriptClass("GlitchyEngine.Serialization", "EntitySerializer", image);

		s_Collision2D = new ScriptClass("GlitchyEngine.Physics", "Collision2D", image);

		// Attributes
		s_RunInEditModeAttribute = new ScriptClass("GlitchyEngine.Editor", "RunInEditModeAttribute", image);
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

	private static append EngineClasses _classes = .();

	public static EngineClasses Classes => _classes;

	private static Dictionary<StringView, ScriptClass> _entityScripts = new .() ~ DeleteDictionaryAndReleaseValues!(_);

	internal static Dictionary<UUID, ScriptInstance> _entityScriptInstances = new .() ~ {
		for (var entry in _)
		{
			entry.value?.ReleaseRef();
		}
		delete _;
	}

	public static Dictionary<StringView, ScriptClass> EntityClasses => _entityScripts;

	/// Gets or sets the current scene context for the runtime.
	public static Scene Context
	{
		get => s_Context;
		private set => SetReference!(s_Context, value);
	}
	
	private static FileSystemWatcher _userAssemblyWatcher ~ delete _;

	// TODO: This should be a global setting somewhere
	private static bool _debuggingEnabled = false;

	private static String _appAssemblyPath = new .() ~ delete _;

	public class ApplicationData
	{
		private bool _isEditor;
		private bool _isPlayer;

		private bool _isInEditMode;
		private bool _isInPlayMode;

		public bool IsEditor
		{
			get => _isEditor;
			set
			{
				_isEditor = value;

				if (_isEditor)
					_isPlayer = false;
			}
		}
		
		public bool IsPlayer
		{
			get => _isPlayer;
			set
			{
				_isPlayer = value;

				if (_isPlayer)
					_isEditor = false;
			}
		}
		
		public bool IsInEditMode
		{
			get => _isInEditMode;
			set
			{
				_isInEditMode = value;

				if (_isInEditMode)
					_isInPlayMode = false;
			}
		}

		public bool IsInPlayMode
		{
			get => _isInPlayMode;
			set
			{
				_isInPlayMode = value;

				if (_isInPlayMode)
					_isInEditMode = false;
			}
		}
	}

	private static ApplicationData _applicationData = new ApplicationData() ~ delete _;

	/// Contains information about the application context
	public static ApplicationData ApplicationInfo => _applicationData;

	public static void Init()
	{
		InitMono();

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
		Mono.mono_set_assemblies_path("mono/lib/4.5");

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
	
	static bool _requestingReload = false;

	static void InitAssemblyWatcher()
	{
		// We don't need a file system watcher, if we have nothing to watch...
		if (!File.Exists(_appAssemblyPath))
			return;

		String directory = scope .();
		Path.GetDirectoryPath(_appAssemblyPath, directory);

		String fileName = scope .("*/");
		Path.GetFileName(_appAssemblyPath, fileName);

		if (_userAssemblyWatcher == null)
		{
			_userAssemblyWatcher = new FileSystemWatcher(directory, fileName);
			_userAssemblyWatcher.OnChanged.Add(new (fileName) =>
			{
				_userAssemblyWatcher.StopRaisingEvents();
				
				if (_requestingReload)
					return;

				_requestingReload = true;

				Log.EngineLogger.Info("Script reload requested.");

				Application.Instance.InvokeOnMainThread(new () =>
				{
					ReloadAssemblies();
					
					_requestingReload = false;
					_userAssemblyWatcher.StartRaisingEvents();
				});
	
			});
		}

		_userAssemblyWatcher.StartRaisingEvents();
	}

	static void LoadScriptAssemblies()
	{
		Debug.Profiler.ProfileFunction!();

		ScriptGlue.Init();

		CreateAppDomain("GlitchyEngineScriptRuntime");
		(s_CoreAssembly, s_CoreAssemblyImage) = LoadAssembly("resources/scripts/ScriptCore.dll", _debuggingEnabled);

		if (File.Exists(_appAssemblyPath))
			(s_AppAssembly, s_AppAssemblyImage) = LoadAssembly(_appAssemblyPath, _debuggingEnabled);
		else
		{
			s_AppAssembly = null;
			s_AppAssemblyImage = null;
		}

		Classes.LoadClasses(s_CoreAssemblyImage);

		ClearDictionaryAndReleaseValues!(_entityScripts);

		GetEntitiesFromAssemblies();

		ScriptGlue.RegisterManagedComponents();

		InitAssemblyWatcher();
	}

	/// Starts the script runtime and sets the context scene.
	public static void StartRuntime(Scene context)
	{
		Debug.Assert(s_Context == null, "StartRuntime was called twice without StopRuntime in between!");
		Context = context;

		ReloadAssemblies();
	}

	/// Stopts the script runtime and disposes of all script instances.
	public static void StopRuntime()
	{
		if (Context == null)
		{
			// There should be nothing to do, if we have no context
			Debug.Assert(_entityScriptInstances.Count == 0, "There are script instances but no context scene.");
			return;
		}

		for (let (id, instance) in _entityScriptInstances)
		{
			instance?.ReleaseRef();

			Entity entity = Context.GetEntityByID(id);

			// Remove Instance from script
			ScriptComponent* script = entity.GetComponent<ScriptComponent>();
			script.Instance = null;
		}
		_entityScriptInstances.Clear();

		Context = null;
	}

	/// Instantiates the entities script components script and runs the constructor.
	/// Disposes of and replaces the old instance, if one exists.
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

		DestroyInstance(entityId);
	}

	public static void DestroyInstance(UUID entityId)
	{
		if (_entityScriptInstances.TryGetValue(entityId, let currentInstance))
			currentInstance.ReleaseRef();
	}

	internal static void UnregisterScriptInstance(UUID entityId)
	{
		_entityScriptInstances.Remove(entityId);
	}

	private static MonoAssembly* LoadCSharpAssembly(StringView assemblyPath, bool loadPDB = false)
	{
		Debug.Profiler.ProfileFunction!();

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
		Debug.Profiler.ProfileFunction!();

		MonoAssembly* assembly = LoadCSharpAssembly(filepath, loadPDB);
		MonoImage* image = Mono.mono_assembly_get_image(assembly);

		return (assembly, image);
	}

	private static void GetEntitiesFromAssemblies()
	{
		Debug.Profiler.ProfileFunction!();

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
			if (monoClass != null && Mono.mono_class_is_subclass_of(monoClass, Classes.EntityRoot.[Friend]_monoClass, false))
			{
				ScriptClass entityScript = new ScriptClass(StringView(nameSpace), StringView(name), s_AppAssemblyImage);
				_entityScripts.Add(entityScript.FullName, entityScript);

				Log.EngineLogger.Info($"Added entity \"{entityScript.FullName}\"");
			}
	    }
	}

	public static void ReloadAssemblies()
	{
		Debug.Profiler.ProfileFunction!();

		Log.EngineLogger.Info("Reloading script assemblies.");

		ScriptInstanceSerializer contextSerializer = scope .();

		contextSerializer.SerializeScriptInstances();

		Mono.mono_domain_set(s_RootDomain, true);

		Mono.mono_domain_unload(s_AppDomain);

		LoadScriptAssemblies();

		{
			Debug.Profiler.ProfileScope!("Initialize Instances");
			
			// We need to create a new instance for every entity
			for (let (id, scriptInstance) in _entityScriptInstances)
			{
				if (Context.GetEntityByID(id) case .Ok(let entity))
				{
					ScriptComponent* script = entity.GetComponent<ScriptComponent>();
					InitializeInstance(entity, script);
				}
				else
				{
					Log.EngineLogger.AssertDebug(false, "Entities script was just serialized but the entity doesn't exist anymore.");
				}
			}
		}

		contextSerializer.DeserializeScriptInstances();

		Log.EngineLogger.Info("Script assemblies reloaded!");
	}

	public static void Shutdown()
	{
		Mono.mono_domain_set(s_RootDomain, false);

		Mono.mono_domain_unload(s_AppDomain);
		s_AppDomain = null;

		Mono.mono_jit_cleanup(s_RootDomain);
		s_RootDomain = null;
	}

	/// Returns the script instance or null.
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

	internal static void HandleMonoException(MonoException* exception, UUID entityId)
	{
		MonoExceptionHelper wrappedException = new MonoExceptionHelper(exception);

		String entityInfo = scope .();

		if (entityId != .Zero)
		{
			wrappedException.Instance = entityId;

			Result<Entity> sourceEntity = Context.GetEntityByID(entityId);

			if (sourceEntity case .Ok(let e))
			{
				entityInfo.AppendF($" ({e.Name} | {entityId})");
			}
		}

		Log.ClientLogger.Error($"Mono Exception \"{wrappedException.FullName}\": \"{wrappedException.Message}\"{entityInfo}\nStackTrace:\n{wrappedException.StackTrace}", wrappedException);

		wrappedException.ReleaseRef();
	}

	internal static void HandleMonoException(MonoException* exception, ScriptInstance sourceInstance = null)
	{
		HandleMonoException(exception, sourceInstance?.EntityId ?? .Zero);
	}

	public static void ShowScriptEditor(Entity entity, ScriptComponent* scriptComponent)
	{
		if (scriptComponent.Instance == null)
			return;
		
		Classes.EntityEditor.ShowEntityEditor(scriptComponent.Instance, entity.UUID);
	}
}

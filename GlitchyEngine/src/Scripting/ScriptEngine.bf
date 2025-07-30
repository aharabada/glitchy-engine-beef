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
	// TODO: Not all of these are actually ScriptClasses (actually none of them are...)
	
	private NewScriptClass s_EngineObject;
	private NewScriptClass s_ComponentRoot;
	private NewScriptClass s_EntityRoot;

	private EntityEditorWrapper s_EntityEditor;

	private EntitySerializerWrapper s_EntitySerializer;
	//private NewScriptClass s_SerializationContext;

	private NewScriptClass s_Collision2D;

	private NewScriptClass s_RunInEditModeAttribute;
	
	public NewScriptClass EngineObject => s_EngineObject;
	public NewScriptClass ComponentRoot => s_ComponentRoot;
	public NewScriptClass EntityRoot => s_EntityRoot;

	public EntityEditorWrapper EntityEditor => s_EntityEditor;

	public EntitySerializerWrapper EntitySerializer => s_EntitySerializer;

	public NewScriptClass Collision2D => s_Collision2D;

	public NewScriptClass RunInEditModeAttribute => s_RunInEditModeAttribute;

	public ~this()
	{
		ReleaseAndNullify();
	}

	internal void ReleaseAndNullify()
	{
		DeleteAndNullify!(s_EngineObject);
		DeleteAndNullify!(s_EntityRoot);
		DeleteAndNullify!(s_ComponentRoot);

		DeleteAndNullify!(s_EntityEditor);

		DeleteAndNullify!(s_EntitySerializer);
		//ReleaseRefAndNullify!(s_SerializationContext);

		DeleteAndNullify!(s_Collision2D);

		DeleteAndNullify!(s_RunInEditModeAttribute);
	}

	internal void LoadClasses()
	{
		ReleaseAndNullify();

		s_EngineObject = new NewScriptClass("GlitchyEngine.Core.EngineObject", .Empty, .None);
		s_EntityRoot = new NewScriptClass("GlitchyEngine.Core.Entity", .Empty, .None);
		s_ComponentRoot = new NewScriptClass("GlitchyEngine.Core.Component", .Empty, .None);

		// Editor classes
		s_EntityEditor = new EntityEditorWrapper();

		s_EntitySerializer = new EntitySerializerWrapper();

		s_Collision2D = new NewScriptClass("GlitchyEngine.Physics.Collision2D", .Empty, .None);

		// Attributes
		s_RunInEditModeAttribute = new NewScriptClass("GlitchyEngine.Editor.RunInEditModeAttribute", .Empty, .None);
	}
}

static class ScriptEngine
{
	private static Scene s_Context ~ _?.ReleaseRef();

	private static EngineClasses _classes = new .() ~ delete _;

	public static EngineClasses Classes => _classes;

	private static Dictionary<StringView, NewScriptClass> _entityScripts = new .() ~ DeleteDictionaryAndValues!(_);

	internal static Dictionary<UUID, NewScriptInstance> _entityScriptInstances = new .() ~ {
		for (var entry in _)
		{
			entry.value?.ReleaseRef();
		}
		delete _;
	}

	public static Dictionary<StringView, NewScriptClass> EntityClasses => _entityScripts;

	/// Gets or sets the current scene context for the runtime.
	public static Scene Context
	{
		get => s_Context;
		private set => SetReference!(s_Context, value);
	}
	
	private static FileSystemWatcher _userAssemblyWatcher ~ delete _;

	// TODO: This should be a global setting somewhere
	private static bool _debuggingEnabled = true;

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
		InitRuntime();
		//InitMono();

		LoadScriptAssemblies();
	}

	/// Changes the path to the current app assembly.
	public static void SetAppAssemblyPath(StringView appAssemblyPath)
	{
		_appAssemblyPath.Set(appAssemblyPath);

		ReloadAssemblies();
	}

	static void InitRuntime()
	{
		// TODO: We currently have the utility methods (e.g. assembly loading) in ScriptCore,
		// the problem is, that CoreCLR currently can't unload the initial assembly.
		// this means that we cannot easily reload changes to ScriptCore.
		// Since this basic infrastructure shouldn't really ever change we could make a tiny
		// library with only that enabling us to reload script core.
		CoreClrHelper.Init("resources/scripts/ScriptCore.dll");
	}	

	/*static void InitMono()
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
	}*/
	
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

					return true;
				});
	
			});
		}

		_userAssemblyWatcher.StartRaisingEvents();
	}

	static void LoadScriptAssemblies()
	{
		Debug.Profiler.ProfileFunction!();
		
		// TODO: We should probably verify, that all required types actually exist.
		Classes.LoadClasses();

		ScriptGlue.Init();
		
		// TODO: Check if files exist
		if (File.Exists(_appAssemblyPath))
		{
			List<uint8> data = scope List<uint8>();
			File.ReadAll(_appAssemblyPath, data);

			List<uint8> pdbData = scope List<uint8>();

			String pdbPath = scope .();
			Path.ChangeExtension(_appAssemblyPath, ".pdb", pdbPath);

			File.ReadAll(pdbPath, pdbData);

			CoreClrHelper.LoadAppAssembly(data, pdbData);
			
			GetEntitiesFromAssemblies();
			
			//ScriptGlue.RegisterManagedComponents();
		}

		//InitAssemblyWatcher();
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
		Log.EngineLogger.Error($"{Compiler.CallerMemberName} not updated yet.");

		NewScriptClass scriptClass = GetScriptClass(script.ScriptClassName);

		if (scriptClass == null)
			return false;

		UUID entityId = entity.UUID;

		script.Instance = new NewScriptInstance(entityId, scriptClass);
		script.Instance..ReleaseRef();

		if (_entityScriptInstances.TryGetValue(entityId, let currentInstance))
			currentInstance.ReleaseRef();

		_entityScriptInstances[entityId] = script.Instance..AddRef();

		script.Instance.Instantiate();

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

	public enum ScriptMethods : uint32
	{
	    None = 0,
	    OnCreate = 0x1,
	    OnUpdate = 0x2,
	    OnDestroy = 0x4,
	}

	struct ScriptClassInfo
	{
		public char8* Name;
		public Guid Guid;
		public ScriptMethods Methods;
		public bool RunInEditMode;
	}

	private static void GetEntitiesFromAssemblies()
	{
		Debug.Profiler.ProfileFunction!();

		CoreClrHelper.GetScriptClasses(let data, let entryCount);
		
		Span<ScriptClassInfo> scriptClasses = .((.)data, entryCount);
		
		List<NewScriptClass> newClasses = scope .();

		ClearDictionaryAndDeleteValues!(_entityScripts);

		for (var entry in scriptClasses)
		{
			NewScriptClass scriptClass = new .(StringView(entry.Name), entry.Guid, entry.Methods, entry.RunInEditMode);

			newClasses.Add(scriptClass);
		}

		for (var scriptClass in newClasses)
		{
			_entityScripts.Add(scriptClass.FullName, scriptClass);
		}

		CoreClrHelper.FreeScriptClassNames();
	}

	public static void ReloadAssemblies()
	{
		Debug.Profiler.ProfileFunction!();

		Log.EngineLogger.Info("Reloading script assemblies.");


		ScriptInstanceSerializer contextSerializer = scope .();

		contextSerializer.SerializeScriptInstances();

		// TODO: Unload script assemblies, remove class handles, fire unload events?

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
		/*Mono.mono_domain_set(s_RootDomain, false);

		Mono.mono_domain_unload(s_AppDomain);
		s_AppDomain = null;

		Mono.mono_jit_cleanup(s_RootDomain);
		s_RootDomain = null;*/
	}

	// TODO: Do we still need this? It was only called by ScriptGlue
	/// Returns the script instance or null.
	public static void* GetManagedInstance(UUID entityId)
	{
		//if (_entityScriptInstances.TryGetValue(entityId, let scriptInstance))
		//	return scriptInstance.MonoInstance;

		return null;
	}

	public static NewScriptClass GetScriptClass(StringView name)
	{
		EntityClasses.TryGetValue(name, let scriptClass);

		return scriptClass;
	}

	internal static void LogScriptException(ScriptException exception, UUID entityId)
	{
		String entityInfo = scope .();

		if (entityId != .Zero)
		{
			exception.EntityId = entityId;

			Result<Entity> sourceEntity = Context.GetEntityByID(entityId);

			if (sourceEntity case .Ok(let e))
			{
				entityInfo.AppendF($" ({e.Name} | {entityId})");
			}
		}

		Log.ClientLogger.Error($"Exception \"{exception.FullName}\": \"{exception.Message}\"{entityInfo}\nStackTrace:\n{exception.StackTrace}", exception);
	}

	// TODO: Wrap like the other classes
	public static void ShowScriptEditor(Entity entity, ScriptComponent* scriptComponent)
	{
		if (scriptComponent.Instance == null)
			return;
		
		Classes.EntityEditor.ShowEntityEditor(scriptComponent.Instance, entity.UUID);
	}
}

using GlitchyEngine.World;
using ImGui;
using System;
using System.Collections;
using GlitchyEngine.Collections;
using GlitchyEditor.EditWindows;
using GlitchyEngineHelper;
using System.IO;

namespace GlitchyEditor
{
	class Editor
	{
		private EcsWorld _ecsWorld;
		private Scene _scene;
		
		private EntityHierarchyWindow _entityHierarchyWindow ~ delete _;
		private ComponentEditWindow _componentEditWindow ~ delete _;
		private SceneViewportWindow _sceneViewportWindow = new .(this) ~ delete _;

		private List<EcsEntity> _selectedEntities = new .() ~ delete _;

		public EcsWorld World => _ecsWorld;

		public List<EcsEntity> SelectedEntities => _selectedEntities;

		public EntityHierarchyWindow EntityHierarchyWindow => _entityHierarchyWindow;
		public ComponentEditWindow ComponentEditWindow => _componentEditWindow;
		public SceneViewportWindow SceneViewportWindow => _sceneViewportWindow;

		[CRepr]
		struct lib_args
		{
		    public char16* Message;
		    public int32 number;
		};

		[CRepr]
		struct CreateInstanceArgs
		{
		    //public StringView TypeName;
			public char8* TypeName;
			public int TypeNameLength;
		};
		
		struct ManagedReference;

		public typealias CreateInstanceDelegate = function [CallingConvention(.Stdcall)] ManagedReference*(CreateInstanceArgs* arg, int32 arg_size_in_bytes);

		public typealias FreeInstanceDelegate = function [CallingConvention(.Stdcall)] void(ManagedReference* arg);

		public typealias InstanceMethodDelegate = function [CallingConvention(.Stdcall)] void(ManagedReference* arg);

		/// Creates a new editor for the given world
		public this(Scene scene)
		{
			String exePath = Environment.GetExecutableFilePath(.. scope String());

			String exeDir = Path.GetDirectoryPath(exePath, .. scope String());

			String runtimeConfig = scope String(exeDir, "/DotNetScriptingHelper.runtimeconfig.json");
			String assemblyPath = scope String(exeDir, "/DotNetScriptingHelper.dll");

			DotNet dotty = new DotNet(assemblyPath);
			defer delete dotty;

			dotty.Init();

			///int res = dotty.SetRuntimePropertyValue("APP_PATH", exeDir);

			CreateInstanceDelegate createInstance;
			dotty.GetFunctionPointerUnmanagedCallersOnly("DotNetScriptingHelper.InteropHelper, DotNetScriptingHelper", "CreateInstance", out createInstance);
			
			String typeName = "DotNetScriptingHelper.TestEntityScript, DotNetScriptingHelper";

			CreateInstanceArgs instanceArgs = .
			{
				TypeName = typeName.Ptr,
				TypeNameLength = typeName.Length
			};

			ManagedReference* instance = createInstance(&instanceArgs, sizeof(CreateInstanceArgs));
			
			InstanceMethodDelegate update;
			dotty.GetFunctionPointerUnmanagedCallersOnly("DotNetScriptingHelper.ScriptableEntity, DotNetScriptingHelper", "UpdateEntity", out update);
			
			InstanceMethodDelegate freeInstance;
			dotty.GetFunctionPointerUnmanagedCallersOnly("DotNetScriptingHelper.ScriptableEntity, InteropHelper", "FreeInstance", out freeInstance);

			//void* reffy = DotNetScriptComponent.DelCreateInstance(typeName.Ptr, (int32)typeName.Length, EcsEntity.[Friend]CreateEntityID(1337, 420));

			for (int i < 10)
			{
				update(instance);
				//update((.)reffy);
			}

			freeInstance(instance);
			/*
			freeInstance(instance);
			freeInstance((.)reffy);*/

			//DotNetRuntime.Deinit();

			/*DotNetRuntime.Init();

			DotNetRuntime.LoadRuntime(runtimeConfig);

			CreateInstanceDelegate createInstance;
			DotNetRuntime.LoadAssemblyAndGetFunctionPointerUnmanagedCallersOnly(assemblyPath, "DotNetScriptingHelper.InteropHelper, DotNetScriptingHelper", "CreateInstance", out createInstance);

			DotNetRuntime.ManagedDelegate someDel1;
			DotNetRuntime.ManagedDelegate someDel2;

			DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetScriptingHelper.InteropHelper, DotNetScriptingHelper", "SomeMethod", out someDel1);

			someDel1(null, 0); // System.Runtime.InteropServices.Marshal, System.Private.CoreLib, Version=6.0.0.0, Culture=neutral, PublicKeyToken=7cec85d7bea7798e

			int32 iy = DotNetRuntime.GetFunctionPointer("DotNetScriptingHelper.InteropHelper, DotNetScriptingHelper, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null", "SomeMethod", out someDel2);
			//DotNetRuntime.GetFunctionPointer("System", DotNetScriptingHelper", "SomeMethod", out someDel2);
			/*
			FreeInstanceDelegate freeInstance = null;
			//DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetScriptingHelper.InteropHelper, DotNetScriptingHelper", "FreeInstance", "DotNetScriptingHelper.InteropHelper+FreeInstanceEntryPoint, DotNetScriptingHelper", out freeInstance);
			DotNetRuntime.GetFunctionPointer("DotNetScriptingHelper.InteropHelper, DotNetScriptingHelper", "FreeInstance", "DotNetScriptingHelper.InteropHelper+FreeInstanceEntryPoint, DotNetScriptingHelper", out freeInstance);
			
			InstanceMethodDelegate update;
			DotNetRuntime.GetFunctionPointerUnmanagedCallersOnly("DotNetScriptingHelper.ScriptableEntity, DotNetScriptingHelper", "UpdateEntity", out update);
			
			DotNetRuntime.GetFunctionPointerUnmanagedCallersOnly("DotNetScriptingHelper.ScriptableEntity, DotNetScriptingHelper", "CreateInstance", out DotNetScriptComponent.DelCreateInstance);

			String typeName = "DotNetScriptingHelper.TestEntityScript, DotNetScriptingHelper";

			CreateInstanceArgs instanceArgs = .
			{
				TypeName = typeName.Ptr,
				TypeNameLength = typeName.Length
			};

			ManagedReference* instance = createInstance(&instanceArgs, sizeof(CreateInstanceArgs));

			void* reffy = DotNetScriptComponent.DelCreateInstance(typeName.Ptr, (int32)typeName.Length, EcsEntity.[Friend]CreateEntityID(1337, 420));

			for (int i < 10)
			{
				update(instance);
				update((.)reffy);
			}

			freeInstance(instance);
			freeInstance((.)reffy);

			DotNetRuntime.Deinit();

			*/*/

			while(true)
			{

			}

			_scene = scene;
			_ecsWorld = _scene.[Friend]_ecsWorld;

			_entityHierarchyWindow = new EntityHierarchyWindow(_scene);
			_componentEditWindow = new ComponentEditWindow(_entityHierarchyWindow);
		}

		public void Update()
		{
			_entityHierarchyWindow.Show();
			_componentEditWindow.Show();
			_sceneViewportWindow.Show();
		}

		/// Creates a new entity with a transform component.
		internal EcsEntity CreateEntityWithTransform()
		{
			var entity = _ecsWorld.NewEntity();

			var transformComponent = ref *_ecsWorld.AssignComponent<TransformComponent>(entity);
			transformComponent = TransformComponent();

			var nameComponent = ref *_ecsWorld.AssignComponent<DebugNameComponent>(entity);
			nameComponent.SetName("Entity");

			return entity;
		}

		
		/// Returns whether or not all selected entities have the same parent.
		internal bool AllSelectionsOnSameLevel()
		{
			EcsEntity? parent = .InvalidEntity;

			for(var selectedEntity in _selectedEntities)
			{
				var parentComponent = _ecsWorld.GetComponent<ParentComponent>(selectedEntity);

				if(parent == .InvalidEntity)
				{
					parent = parentComponent?.Entity;
				}
				else if(parentComponent?.Entity != parent)
				{
					return false;
				}
			}

			return true;
		}

		/// Finds all children of the given entity and stores their IDs in the given list.
		internal void FindChildren(EcsEntity entity, List<EcsEntity> entities)
		{
			for(var (child, childParent) in _ecsWorld.Enumerate<ParentComponent>())
			{
				if(childParent.Entity == entity)
				{
					if(!entities.Contains(child))
						entities.Add(child);

					FindChildren(child, entities);
				}
			}
		}

		/// Deletes all selected entities and their children.
		internal void DeleteSelectedEntities()
		{
			List<EcsEntity> entities = scope .();

			for(var entity in _selectedEntities)
			{
				entities.Add(entity);

				FindChildren(entity, entities);
			}

			for(var entity in entities)
			{
				_ecsWorld.RemoveEntity(entity);
			}

			_selectedEntities.Clear();
		}
	}
}

using GlitchyEngine.World;
using ImGui;
using System;
using System.Collections;
using GlitchyEngine.Collections;
using GlitchyEditor.EditWindows;
using GlitchyEngineHelper;

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
			String str = @"D:\Development\Projects\Beef\GlitchyEngine\build\Debug_Win64\GlitchyEditor\";
			//char16* ptr = str.ToScopedNativeWChar!();

			String runtimeConfig = scope String(str, "DotNetTest.runtimeconfig.json");
			String assemblyPath = scope String(str, "DotNetTest.dll");

			DotNetRuntime.Init();

			DotNetRuntime.LoadRuntime(runtimeConfig);



			DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetTest.Lib, DotNetTest", "Hello", let hello);
			DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetTest.ScriptableEntity, DotNetTest", "Hello2", let hello2);


			DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetTest.InteropHelper, DotNetTest", "Test", let test);

			CreateInstanceDelegate createInstance;
			//DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetTest.InteropHelper, DotNetTest", "CreateInstance", "DotNetTest.InteropHelper+CreateInstanceEntryPoint, DotNetTest", out createInstance);
			DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetTest.InteropHelper, DotNetTest", "CreateInstance", out createInstance);
			
			FreeInstanceDelegate freeInstance;
			//DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetTest.InteropHelper, DotNetTest", "FreeInstance", "DotNetTest.InteropHelper+FreeInstanceEntryPoint, DotNetTest", out freeInstance);
			DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetTest.InteropHelper, DotNetTest", "FreeInstance", out freeInstance);
			
			InstanceMethodDelegate update;
			//DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetTest.ScriptableEntity, DotNetTest", "InvokeUpdate", "DotNetTest.ScriptableEntity+InstanceMethodEntryPoint, DotNetTest", out update);
			DotNetRuntime.LoadAssemblyAndGetFunctionPointer(assemblyPath, "DotNetTest.ScriptableEntity, DotNetTest", "InvokeUpdate", out update);

			//DotNetRuntime.TestRunDotNet(1, &ptr);

			lib_args args = .
			{
			    Message = "from host!".ToScopedNativeWChar!(),
			    number = 1337
			};

			hello(&args, sizeof(lib_args));

			hello2(&args, sizeof(lib_args));

			test(null, 0);

			String typeName = "DotNetTest.ScriptableEntity, DotNetTest";

			CreateInstanceArgs instanceArgs = .
			{
				TypeName = typeName.Ptr,
				TypeNameLength = typeName.Length
			};

			ManagedReference* instance = createInstance(&instanceArgs, sizeof(CreateInstanceArgs));

			for (int i < 10)
			{
				update(instance);
			}

			freeInstance(instance);

			DotNetRuntime.Deinit();

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

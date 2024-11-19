using Ultralight.CAPI;
using System;
using GlitchyEngine;
using GlitchyEngine.Collections;
using GlitchyEngine.World;
using System.Collections;
using GlitchyEngine.Core;
using System.Reflection;
using GlitchyEngine.World.Components;
using static GlitchyEngine.UI.Window;

namespace GlitchyEditor.Ultralight;

class UltralightMainWindow : UltralightWindow
{
	public this() : base("Glitchy Engine", "file:///index.html")
	{

	}

	public override void Update()
	{
		UpdateEntityHierarchy();
	}

	struct EntityEntry : IDisposable
	{
		public Entity Entity;
		public String Name;
		public UUID ParentId;
		public List<UUID> Children;
		public bool Visible;

		public this(Entity entity, StringView name, UUID parentId, bool visible)
		{
			Entity = entity;
			Name = new String(name);
			ParentId = parentId;
			Children = new List<UUID>();
			Visible = visible;
		}

		public void Dispose()
		{
			delete Name;
			delete Children;
		}
	}

	Dictionary<UUID, EntityEntry> _entities = new .() ~ DeleteDictionaryAndDisposeValues!(_);

	bool _forceEntityHierarchyRebuild = false;

	enum Operation
	{
		None,
		Add,
		Delete,
		Modify
	}

	private void UpdateEntityHierarchy()
	{
		if (uiCallUpdateEntities == null)
		{
			Log.EngineLogger.Error($"{nameof(uiCallUpdateEntities)} is null, skipping entity hierarchy update.");
			return;
		}

		Dictionary<UUID, Operation> updates = scope .();
		GetEntityUpdates(updates);
		SendUpdateToUI(updates);
	}

	private void GetEntityUpdates(Dictionary<UUID, Operation> updates)
	{
		Scene scene = Editor.Instance.CurrentScene;

		// If we have no root, or the scene changed, rebuild the entire tree
		if (_forceEntityHierarchyRebuild || !_entities.ContainsKey(.Zero) || scene != _entities[.Zero].Entity.Scene)
		{
			_forceEntityHierarchyRebuild = false;

			ClearDictionaryAndDisposeValues!(_entities);

			_entities.Add(.Zero, EntityEntry(Entity(.InvalidEntity, scene), "Root", .Zero, true));
		}

		// TODO: entity.EditorFlags.HasFlag(.HideInHierarchy)

		EntityEntry AddEntity(Entity entity)
		{
			UUID entityId = entity.UUID;

			if (!_entities.TryGetValue(entityId, var entry))
			{
				Entity? parent = entity.Parent;

				entry = EntityEntry(entity, entity.Name, parent?.UUID ?? .Zero, !entity.EditorFlags.HasFlag(.HideInScene));

				_entities.Add(entityId, entry);
				updates[entityId] = .Add;

				//if (parent != null)
				//{
				UUID parentId = parent?.UUID ?? .Zero;

				if (!_entities.TryGetValue(parentId, var parentEntry))
				{
					parentEntry = AddEntity(parent.Value);
				}
				else
				{
					updates[parentId] = .Modify;
				}

				parentEntry.Children.Add(entityId);
				//}
			}

			return entry;
		}

		for (let (entityId, entityEntry) in ref _entities)
		{
			// Root node isn't a real entity
			if (entityId == .Zero)
				continue;

			if (scene.GetEntityByID(entityId) case .Ok(let sceneEntity))
			{
				bool changed = false;

				if (entityEntry.Name != sceneEntity.Name)
				{
					entityEntry.Name.Set(sceneEntity.Name);
					changed = true;
				}

				Entity? parentEntity = sceneEntity.Parent;
				UUID newParentEntityId = parentEntity?.UUID ?? .Zero;
				UUID oldParentEntityId = entityEntry.ParentId;

				if (oldParentEntityId != newParentEntityId)
				{
					if (!_entities.TryGetValue(newParentEntityId, var newParentEntry))
					{
						newParentEntry = AddEntity(parentEntity.Value);
					}
					newParentEntry.Children.Add(entityId);
					updates[newParentEntityId] = .Modify;
					
					if (_entities.TryGetValue(oldParentEntityId, var oldParentEntry))
					{
						oldParentEntry.Children.Remove(entityId);
						updates[oldParentEntityId] = .Modify;
					}

					entityEntry.ParentId = newParentEntityId;
					changed = true;
				}

				if (changed)
				{
					updates[entityId] = .Modify;
				}
			}
			else
			{
				entityEntry.Dispose();

				_entities.Remove(entityId);
				updates[entityId] = .Delete;
			}
		}

		for (EcsEntity entityId in scene.GetEntities())
		{
			let entity = Entity(entityId, scene);

			AddEntity(entity);
		}
	}

	private void SendUpdateToUI(Dictionary<UUID, Operation> updates)
	{
		if (updates.Count == 0)
			return;

		JSContextRef context = ulViewLockJSContext(_view);
		defer ulViewUnlockJSContext(_view);
		
		JSStringRef nameProperty = JSStringCreateWithUTF8CString("name");
		JSStringRef idProperty = JSStringCreateWithUTF8CString("id");
		JSStringRef visibleProperty = JSStringCreateWithUTF8CString("visible");
		JSStringRef childrenProperty = JSStringCreateWithUTF8CString("children");
		defer JSStringRelease(nameProperty);
		defer JSStringRelease(idProperty);
		defer JSStringRelease(visibleProperty);
		defer JSStringRelease(childrenProperty);
		
		JSObjectRef jsArray = JSObjectMakeArray(context, 0, null, null);
		uint32 index = 0;

		String id = scope .(18);

		for (let (entityId, operation) in updates)
		{
			if (operation == .None)
			{
				continue;
			}

			JSObjectRef jsEntity = JSObjectMake(context, null, null);

			entityId.ToString(id..Clear());

			JSValueRef idObject = UltralightHelper.CreateObjectFromString(context, id);
			JSObjectSetProperty(context, jsEntity, idProperty, idObject, 0, null);

			if (operation != .Delete)
			{
				EntityEntry entry = _entities[entityId];
			
				JSValueRef nameObject = UltralightHelper.CreateObjectFromString(context, entry.Name);
				JSObjectSetProperty(context, jsEntity, nameProperty, nameObject, 0, null);

				JSValueRef visibleObject = JSValueMakeBoolean(context, true);
				JSObjectSetProperty(context, jsEntity, visibleProperty, visibleObject, 0, null);

				JSObjectRef childrenArray = JSObjectMakeArray(context, 0, null, null);

				for (let childId in entry.Children)
				{
					childId.ToString(id..Clear());
					JSValueRef childIdObject = UltralightHelper.CreateObjectFromString(context, id);
					JSObjectSetPropertyAtIndex(context, childrenArray, (uint32)@childId.Index, childIdObject, null);
				}

				JSObjectSetProperty(context, jsEntity, childrenProperty, childrenArray, 0, null);
			}

			JSObjectSetPropertyAtIndex(context, jsArray, index, jsEntity, null);
			index++;
		}

		JSValueRef exception = null;
		uiCallUpdateEntities(context, Span<JSValueRef>(&jsArray, 1), &exception);

		if (exception != null)
		{
			/*if (JSValueIsString(context, exception))
			{
				Log.EngineLogger.Error($"Failed to update entities: {StringView(JsStringGet)}");
			}
			else
			{*/
				Log.EngineLogger.Error("Failed to update entities.");
			//}
		}
	}
	
	[BindToJsFunction("requestEntityHierarchyUpdate")]
	void HandleRequestEntityHierarchyUpdate(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		_forceEntityHierarchyRebuild = true;
	}

	private bool _hoveringNonClientArea;

	[BindToJsFunction("handleHoverNonClientArea")]
	void HandleHoverNonClientArea(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		Log.EngineLogger.Info("HandleHoverNonClientArea");

		if (arguments.Length != 1)
		{
			Log.EngineLogger.Error("EngineGlue.setHoverNonClientArea: called with wrong number of arguments.");
			return;
		}

		if (!JSValueIsBoolean(context, arguments[0]))
		{
			Log.EngineLogger.Error($"EngineGlue.setHoverNonClientArea: expected boolean, but received {JSValueGetType(context, arguments[0])} instead.");
			return;
		}

		_hoveringNonClientArea = JSValueToBoolean(context, arguments[0]);

		_window.[Friend]_hoveredOverTitleBar = _hoveringNonClientArea;

		EditorLayer.HoverCap = _window.[Friend]_hoveredOverTitleBar;

		Log.ClientLogger.Info($"_hoveringNonClientArea: {_hoveringNonClientArea}");
	}

	[BindToJsFunction("handleHoverMaximizeWindow")]
	void HandleHoverMaximizeButton(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		HandleHoverTitlebarButton(.Maximize, context, thisObject, arguments, exception);
	}

	[BindToJsFunction("handleHoverMinimizeWindow")]
	void HandleHoverMinimizeButton(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		HandleHoverTitlebarButton(.Minimize, context, thisObject, arguments, exception);
	}
	
	[BindToJsFunction("handleHoverCloseWindow")]
	void HandleHoverCloseButton(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		HandleHoverTitlebarButton(.Close, context, thisObject, arguments, exception);
	}

	void HandleHoverTitlebarButton(TitleBarButton button, JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		if (arguments.Length != 1)
		{
			Log.EngineLogger.Error("EngineGlue.HandleHoverMaximizeWindow: called with wrong number of arguments.");
			return;
		}

		if (!JSValueIsBoolean(context, arguments[0]))
		{
			Log.EngineLogger.Error($"EngineGlue.HandleHoverMaximizeWindow: expected boolean, but received {JSValueGetType(context, arguments[0])} instead.");
			return;
		}

		Enum.SetFlagConditionally(ref _window.[Friend]_hoveredTitleBarButton, button, JSValueToBoolean(context, arguments[0]));
		
		EditorLayer.HoveredTitleBarButton = _window.[Friend]_hoveredTitleBarButton;
	}
	
	[BindToJsFunction("handleClickMaximizeWindow")]
	void HandleClickMaximizeButton(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		_window.ToggleMaximize();
	}

	[BindToJsFunction("handleClickMinimizeWindow")]
	void HandleClickMinimizeButton(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		_window.Minimize();
	}

	[BindToJsFunction("handleClickCloseWindow")]
	void HandleClickCloseButton(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		_window.Close();
	}

	[BindToJsFunction("setEntityVisibility")]
	void HandleSetEntityVisibility(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null)
	{
		if (arguments.Length != 2)
		{
			Log.EngineLogger.Error("EngineGlue.setEntityVisibility: called with wrong number of arguments.");
			return;
		}

		/*if (!JSValueIsNumber(context, arguments[0]))
		{
			Log.EngineLogger.Error($"EngineGlue.setEntityVisibility: expected number as argument 0, but received {JSValueGetType(context, arguments[0])} instead.");
			return;
		}*/

		if (!JSValueIsBoolean(context, arguments[1]))
		{
			Log.EngineLogger.Error($"EngineGlue.setEntityVisibility: expected boolean as argument 1, but received {JSValueGetType(context, arguments[1])} instead.");
			return;
		}

		JSString jsId = scope .(context, arguments[0]);
		String idString = scope .();
		jsId.GetUTF8String(idString);

		if (uint64.Parse(idString) case .Ok(let id))
		{
			bool visible = JSValueToBoolean(context, arguments[1]);
	
			UUID entityId = .((uint64)id);
	
			if (Editor.Instance.CurrentScene.GetEntityByID(entityId) case .Ok(let entity))
			{
				if (entity.TryGetComponent<EditorFlagsComponent>(let flags))
				{
					Enum.SetFlagConditionally(ref flags.Flags, .HideInScene, !visible);
				}
			}
			else
			{
				Log.ClientLogger.Error($"Entity with ID {entityId} doesn't exist.");
			}
		}
	}

	[BindToJsFunction("callFromEngine_updateEntities")]
	private JsFunctionCall uiCallUpdateEntities ~ delete _;

	[BeefMethodBinder]
	protected override void BindBeefMethodsToJsFunctions(OpaqueJSContext* context, OpaqueJSValue* scriptGlue, StdAllocator stdAlloc)
	{
		base.BindBeefMethodsToJsFunctions(context, scriptGlue, stdAlloc);
	}
}

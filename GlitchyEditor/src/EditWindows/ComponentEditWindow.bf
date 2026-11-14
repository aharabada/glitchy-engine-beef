using ImGui;
using GlitchyEngine.World;
using System;
using GlitchyEngine.Math;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine;
using GlitchyEngine.Content;
using GlitchyEngine.Scripting;
using GlitchyEngine.Core;
using GlitchyEngine.World.Components;
using GlitchyEditor.History;
using GlitchyEngine.Renderer.Text;

namespace GlitchyEditor.EditWindows
{
	using internal GlitchyEngine.World.TransformComponent;

	class ComponentEditWindow
	{
		private static uint32 TableId;

		public static void ShowComponents(Entity entity, Type componentType = null)
		{
			float cellPaddingY = ImGui.GetTextLineHeight() / 3.0f;

			ImGui.PushStyleVar(.CellPadding, ImGui.Vec2(ImGui.GetStyle().CellPadding.x, cellPaddingY));

			TableId = ImGui.GetID("properties");

			if (componentType == null && ImGui.BeginTableEx("properties", TableId, 2, .SizingStretchSame | .BordersInner | .Resizable))
			{
				ShowNameComponentEditor(entity);

				ImGui.EndTable();
			}

			ShowComponentEditor<TransformComponent>(componentType, "Transform", entity, => ShowTransformComponentEditor);
			ShowComponentEditor<CameraComponent>(componentType, "Camera", entity, => ShowCameraComponentEditor, => ShowComponentContextMenu<CameraComponent>);
			
			ShowComponentEditor<SpriteRendererComponent>(componentType, "Sprite Renderer", entity, => ShowSpriteRendererComponentEditor, => ShowComponentContextMenu<SpriteRendererComponent>);
			//ShowComponentEditor<CircleRendererComponent>(componentType, "Circle Renderer", entity, => ShowCircleRendererComponentEditor, => ShowComponentContextMenu<CircleRendererComponent>);
			ShowComponentEditor<TextRendererComponent>(componentType, "Text Renderer", entity, => ShowTextRendererComponentEditor, => ShowComponentContextMenu<TextRendererComponent>);

			ShowComponentEditor<MeshRendererComponent>(componentType, "Mesh Renderer", entity, => ShowMeshRendererComponentEditor, => ShowComponentContextMenu<MeshRendererComponent>);
			ShowComponentEditor<LightComponent>(componentType, "Light", entity, => ShowLightComponentEditor, => ShowComponentContextMenu<LightComponent>);
			ShowComponentEditor<MeshComponent>(componentType, "Mesh", entity, => ShowMeshComponentEditor, => ShowComponentContextMenu<MeshComponent>);

			ShowComponentEditor<Rigidbody2DComponent>(componentType, "Rigidbody 2D", entity, => ShowRigidBody2DComponentEditor, => ShowComponentContextMenu<Rigidbody2DComponent>);
			ShowComponentEditor<BoxCollider2DComponent>(componentType, "Box collider 2D", entity, => ShowBoxCollider2DComponentEditor, => ShowComponentContextMenu<BoxCollider2DComponent>);
			ShowComponentEditor<CircleCollider2DComponent>(componentType, "Circle collider 2D", entity, => ShowCircleCollider2DComponentEditor, => ShowComponentContextMenu<CircleCollider2DComponent>);
			ShowComponentEditor<PolygonCollider2DComponent>(componentType, "Polygon collider 2D", entity, => ShowPolygonCollider2DComponentEditor, => ShowComponentContextMenu<PolygonCollider2DComponent>);

			ScriptComponent:
			{
				String scriptComponentName = "Script";

				if (entity.TryGetComponent<ScriptComponent>(let scriptComponent) && scriptComponent.Instance != null)
				{
					scriptComponentName = scope:ScriptComponent $"Script ({scriptComponent.ScriptClassName})";
				}

				ShowComponentEditor<ScriptComponent>(componentType, scriptComponentName, entity, => ShowScriptComponentEditor, => ShowComponentContextMenu<ScriptComponent>);
			}

			ImGui.PopStyleVar();

			if (componentType == null)
			{
				ShowAddComponentButton(entity);
			}
		}

		public static void DrawSceneGUI(Entity entity)
		{
			DrawComponenSceneGUI<PolygonCollider2DComponent>(entity, => ShowPolygonColliderSceneGUI);
		}

		static void ShowPolygonColliderSceneGUI(Entity entity, PolygonCollider2DComponent* collider)
		{
			if (_editVerticesPolygonCollider2D)
			{
				for (int8 i < collider.VertexCount)
				{
					Matrix localToWorld = entity.Transform.WorldTransform * Matrix.Translation(collider.Offset.X, collider.Offset.Y, 0);
					Matrix transform = Matrix.Translation(float3(collider.Vertices[i], 0)) * localToWorld;
					
					if (Handles.ShowGizmo(ref transform, .TRANSLATE_X | .TRANSLATE_Y, true, id: (int32)i))
					{
						transform = localToWorld.Invert() * transform;

						if (let cmd = _currentCommand as ChangeComponentPropertyCommand<PolygonCollider2DComponent, (int8 Index, float2 Position)>
							&& cmd.WidgetId == (uint32)i)
						{
							cmd.NewValue = (i, transform.Translation.XY);
							cmd.Do();
						}
						else
						{
							_currentCommand = new ChangeComponentPropertyCommand<PolygonCollider2DComponent, (int8 Index, float2 Position)>(
								(uint32)i, entity.Scene, entity.UUID, newValue: (i, transform.Translation.XY), oldValue: (i, collider.Vertices[i]),
								applyValue: (entity, component, newValue) => component.Vertices[newValue.Index] = newValue.Position);
							_currentCommand.Do();
						}
					}

					if (Handles.UsedGizmo)
					{
						Editor.Instance.SceneViewportWindow.DisableMousePicking = true;
					}
					else if ((let cmd = _currentCommand as ChangeComponentPropertyCommand<PolygonCollider2DComponent, (int8 Index, float2 Position)>)
							&& cmd.WidgetId == (uint32)i)
					{
						Editor.Instance.HistoryManager.Do(_currentCommand);
						_currentCommand = null;
					}

				}
			}
		}

		private static void DrawComponenSceneGUI<TComponent>(Entity entity, function void(Entity, TComponent*) showSceneGUI) where TComponent: struct, new
		{
			if (!entity.HasComponent<TComponent>())
				return;

			TComponent* component = entity.GetComponent<TComponent>();

			showSceneGUI(entity, component);
		}

		private static void ShowComponentContextMenu<TComponent>(Entity entity, TComponent* component) where TComponent: struct, new
		{
			if (ImGui.MenuItem("Remove Component"))
				entity.RemoveComponent<TComponent>();
		}

		private static void ShowOnlyComponent<TComponent>(UUID entityId, function void(Entity, TComponent*) showComponentEditor) where TComponent: struct, new
		{
			if (Entity entity = Editor.Instance.CurrentScene.GetEntityByID(entityId))
			{
				if (entity.TryGetComponent<TComponent>(let component))
				{
					if (ImGui.BeginPropertyTable("properties", TableId))
					{
						if (entity.TryGetComponent<TComponent>(let actualComponent))
							showComponentEditor(entity, actualComponent);
		
						ImGui.EndTable();
					}
				}
				else
				{
					ImGui.TextWrapped($"ERROR!\n\nEntity {entity.Name} doesn't have a component of type {nameof(TComponent)}.");
				}
			}
			else
			{
				ImGui.TextWrapped($"ERROR!\n\nEntity {entityId} doesn't exist.");
			}
		}

		static PropertiesWindow window = null;

		private static void ShowComponentEditor<TComponent>(Type soloType, String header, Entity entity, function void(Entity, TComponent*) showComponentEditor, function void(Entity, TComponent*) showComponentContextMenu = null) where TComponent: struct, new
		{
			if ((soloType != null && soloType != typeof(TComponent)) || !entity.HasComponent<TComponent>())
				return;

			TComponent* component = entity.GetComponent<TComponent>();

			bool nodeOpen = (soloType != null) || ImGui.CollapsingHeader(header.CStr(), .DefaultOpen | .AllowOverlap | .Framed | .SpanFullWidth);
			
			ImGui.PushID(header.CStr());
			defer { ImGui.PopID(); }
			
			if (ImGui.IsItemActive() && ImGui.IsMouseDragging(.Left) && ImGui.GetIO().KeyAlt && window == null)
			{
				window = new PropertiesWindow(Editor.Instance, .Component(entity.UUID, typeof(TComponent)));
				window.WindowTitle = header;
			}
			else if (!ImGui.GetIO().KeyAlt)
			{
				window = null;
			}

			if (window != null)
			{
				ImGui.SetWindowFocus(window.WindowTitleWithId.ToScopeCStr!());

				ImGui.Vec2 position = ImGui.GetMousePos();
				position.y -= ImGui.GetTextLineHeight() / 2.0f;
				position.x -= 100.0f;

				ImGui.SetWindowPos(window.WindowTitleWithId.ToScopeCStr!(), position);
			}

			if (showComponentContextMenu != null && ImGui.IsItemClicked(.Right))
			{
				ImGui.OpenPopup("component_popup");
			}

			float positionX = ImGui.GetWindowContentRegionMax().x;
			
			float2 buttonSize = ImGui.GetTextLineHeight().XX;
			
			ImGui.PushStyleColor(.Button, ColorRGBA.Transparent);

			if (showComponentContextMenu != null)
			{
				positionX -= buttonSize.X + ImGui.GetStyle().FramePadding.x;
				ImGui.SameLine(positionX);
				positionX -= ImGui.GetStyle().FramePadding.x;
				
				if (ImGui.ImageButton("open_context_menu", EditorIcons.Instance.Icon_ContextMenu, (.)buttonSize))
				{
					ImGui.OpenPopup("component_popup");
				}

				if (ImGui.BeginPopup("component_popup"))
				{
					showComponentContextMenu(entity, component);
					
					ImGui.EndPopup();
				}
			}

			if (ScriptEngine.ApplicationInfo.IsInPlayMode)
			{
				positionX -= buttonSize.X + ImGui.GetStyle().FramePadding.x;
				ImGui.SameLine(positionX);

				if (ImGui.ImageButton("save_to_editor", EditorIcons.Instance.Icon_Save, (.)buttonSize))
				{
					if (Entity editorEntity = Editor.Instance.EditorScene.GetEntityByID(entity.UUID))
					{
						Scene.CopyComponent<TComponent>(entity, editorEntity);
						
						if (typeof(TComponent) == typeof(ScriptComponent))
						{
							// Dirty hack to get to the serialized script instances of the editor scene.
							var serializer = EditorApp.Instance.EditorLayer.[Friend]_scriptSerializer;

							// Dirty hack to remove the old data
							if (serializer.SerializedObjects.GetAndRemove(entity.UUID) case .Ok(let kvPair))
							{
								delete kvPair.value;
							}

							// Just save the new data into the context (what could possibly go wrong?!)
							// this could probably serialize too much data into our context (because we can serialize reference types)
							// and leave a bunch of dangling data in it (because we can serialize reference types)
							serializer.SerializeScriptInstance(((ScriptComponent*)component).Instance);
							// This is also a massive hack to make sure we don't keep references to types, but this also mean we might serialize too much?
							serializer.FinishSerialization();
						}
					}
					else
					{
						ImGui.OpenPopup("###CopyNewEntityToEditor");
					}
				}

				ImGui.AttachTooltip("Save the component to edit mode");
			}

			ImGui.PopStyleColor();
			
			if (ImGui.BeginPopupModal("Create new entity?###CopyNewEntityToEditor"))
			{
				//ImGui.Text("This entity only exists in play mode. Do you want to copy only this component, or all components?");
				ImGui.Text("This entity only exists in play mode.\nSaving will create an entity that only contains this component in edit mode.");
				
				//if (ImGui.Button("Copy only this component"))
				if (ImGui.Button("Ok"))
				{
					Entity editorEntity = Editor.Instance.EditorScene.CreateEntity(entity.Name, entity.UUID);

					Scene.CopyComponent<TComponent>(entity, editorEntity);

					if (typeof(TComponent) == typeof(ScriptComponent))
					{
						// TODO: Copy script data into editor
						// TODO: Somehow get the scriptserializer used to serialize the editor scene
						//scriptSerializer.SerializeScriptInstance(((ScriptComponent*)component).Instance);
					}

					ImGui.CloseCurrentPopup();
				}

				ImGui.SameLine();

				// TODO!
				/*if (ImGui.Button("Copy all components"))
				{
					ImGui.CloseCurrentPopup();
				}

				ImGui.SameLine();
				*/

				if (ImGui.Button("Cancel"))
				{
					ImGui.CloseCurrentPopup();
				}

				ImGui.EndPopup();
			}

			if (nodeOpen && ImGui.BeginPropertyTable("properties", TableId))
			{
				if (entity.TryGetComponent<TComponent>(let actualComponent))
					showComponentEditor(entity, actualComponent);

				ImGui.EndTable();
			}
		}

		private static void ShowNameComponentEditor(Entity entity)
		{
			if (!entity.HasComponent<NameComponent>())
				return;

			char8[256] nameBuffer = default;

			NameComponent* component = entity.GetComponent<NameComponent>();

			StringView name = null;

			if(component != null)
			{
				name = component.Name;
			}
			else
			{
				name = scope:: $"Entity {entity.Handle.[Friend]Index}";
			}

			// Copy name to buffer
			Internal.MemCpy(&nameBuffer, name.Ptr, Math.Min(nameBuffer.Count, name.Length));

			ImGui.PushItemWidth(-1);

			ImGui.PropertyTableStartNewProperty("Name");

			ImGui.PushItemWidth(-1);

			if(ImGui.InputText("##Name", &nameBuffer, nameBuffer.Count, .EnterReturnsTrue))
			{
				if(component == null)
				{
					component = entity.AddComponent<NameComponent>();
				}

				component.Name = StringView(&nameBuffer);
			}
		}

		static IHistorizableCommand _currentCommand;

		private static void HistorizeContinuousEdit<TComponent, TValue>(
			Entity entity,
			TValue currentValue,
			delegate bool(ref TValue currentValue) showWidget,
			ChangeComponentPropertyCommand<TComponent, TValue>.ApplyValueFunction applyValue) where TComponent: struct, new
		{
			TValue oldValue = currentValue;
			var currentValue;

			if (showWidget(ref currentValue))
			{
				if (let cmd = _currentCommand as ChangeComponentPropertyCommand<TComponent, TValue> && cmd.WidgetId == ImGui.GetItemID())
				{
					cmd.NewValue = currentValue;
					cmd.Do();
				}
				else
				{
					_currentCommand = new ChangeComponentPropertyCommand<TComponent, TValue>(ImGui.GetItemID(), entity.Scene, entity.UUID, newValue: currentValue, oldValue: oldValue,
						applyValue);
					_currentCommand.Do();
				}
			}

			if (ImGui.IsItemDeactivatedAfterEdit() && (let cmd = _currentCommand as ChangeComponentPropertyCommand<TComponent, TValue>) && cmd.WidgetId == ImGui.GetItemID())
			{
				Editor.Instance.HistoryManager.Do(_currentCommand);
				_currentCommand = null;
			}
		}

		private static void HistorizeEdit<TComponent, TValue>(
			Entity entity,
			TValue currentValue,
			delegate bool(ref TValue currentValue) showWidget,
			ChangeComponentPropertyCommand<TComponent, TValue>.ApplyValueFunction applyValue) where TComponent: struct, new
		{
			TValue oldValue = currentValue;
			var currentValue;

			if (showWidget(ref currentValue))
			{
				let command = new ChangeComponentPropertyCommand<TComponent, TValue>(
					ImGui.GetItemID(), entity.Scene, entity.UUID,
					newValue: currentValue, oldValue: oldValue,
					applyValue);
				Editor.Instance.HistoryManager.Do(command);
			}
		}

		private static void ShowTransformComponentEditor(Entity entity, TransformComponent* transform)
		{
			float textWidth = ImGui.CalcTextSize("Position".CStr()).x;
			textWidth = Math.Max(textWidth, ImGui.CalcTextSize("Rotation".CStr()).x);
			textWidth = Math.Max(textWidth, ImGui.CalcTextSize("Scale".CStr()).x);

			textWidth += ImGui.GetStyle().FramePadding.x * 3.0f;

			ImGui.PropertyTableStartNewProperty("Position");
			HistorizeContinuousEdit<TransformComponent, float3>(entity, transform.Position,
				showWidget: scope (value) => ImGui.Float3Editor("##Position", ref value, resetValues: .Zero, dragSpeed: 0.1f),
				applyValue: (entity, component, newValue) => {
							component.Position = newValue;

							// if necessary reposition Rigidbody2D
							if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
							{
								rigidbody2D.SetPosition(newValue.XY);
							}
						});

			float3 rotationEuler = MathHelper.ToDegrees(transform.EditorRotationEuler);

			bool3 componentEditable = true;

			if (entity.HasComponent<Rigidbody2DComponent>())
			{
				// Disable X and Y rotation for 2D rigid bodies
				componentEditable.XY = false;
				rotationEuler.XY = 0;
			}

			ImGui.PropertyTableStartNewProperty("Rotation");
			HistorizeContinuousEdit<TransformComponent, float3>(entity, rotationEuler,
				showWidget: scope (value) => ImGui.Float3Editor("##Rotation", ref value, resetValues: .Zero, dragSpeed: 0.1f, componentEnabled: componentEditable, format: .("0.#####°",)),
				applyValue: (entity, component, newRotationEuler) => {
					component.EditorRotationEuler = MathHelper.ToRadians(newRotationEuler);

					// if necessary reposition Rigidbody2D
					if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
					{
						rigidbody2D.SetAngle(newRotationEuler.Z);
					}
				});

			ImGui.PropertyTableStartNewProperty("Scale");
			HistorizeContinuousEdit<TransformComponent, float3>(entity, transform.Scale,
				showWidget: scope (value) => ImGui.Float3Editor("##Scale", ref value, resetValues: .One, dragSpeed: 0.1f),
				applyValue: (entity, component, newScale) => {
					component.Scale = newScale;
				});
		}

		static String[] strings = new String[]("Orthographic", "Perspective", "Perspective (Infinite)") ~ delete _;

		private static void ShowCameraComponentEditor(Entity entity, CameraComponent* cameraComponent)
		{
			ImGui.PropertyTableStartNewProperty("Is Primary");
			HistorizeContinuousEdit<CameraComponent, bool>(entity,
				currentValue: cameraComponent.Primary,
				showWidget: scope (value) => ImGui.Checkbox("##Is_Primary", &value),
				applyValue: (entity, component, newValue) => component.Primary = newValue);

			var camera = ref cameraComponent.Camera;

			ImGui.PropertyTableStartNewProperty("Projection");
			HistorizeEdit<CameraComponent, SceneCamera.ProjectionType>(entity,
				currentValue: camera.ProjectionType,
				showWidget: scope (value) => {
					bool changed = false;
					
					String typeName = strings[camera.ProjectionType.Underlying];
					if (ImGui.BeginCombo("##Projection", typeName.CStr()))
					{
						for (int i = 0; i < 3; i++)
						{
							bool isSelected = (typeName == strings[i]);

							if (ImGui.Selectable(strings[i], isSelected))
							{
								value = (SceneCamera.ProjectionType)i;
								changed = true;
							}

							if (isSelected)
								ImGui.SetItemDefaultFocus();
						}

						ImGui.EndCombo();
					}

					return changed;
				},
				applyValue: (entity, component, newValue) => component.Camera.ProjectionType = newValue);

			if (camera.ProjectionType == .Perspective)
			{
				ImGui.PropertyTableStartNewProperty("Fov Y");
				HistorizeContinuousEdit<CameraComponent, float>(entity,
					currentValue: MathHelper.ToDegrees(camera.PerspectiveFovY),
					showWidget: scope (value) => ImGui.DragFloat("##Fov Y", &value, 0.1f, format: "%.3g°"),
					applyValue: (entity, component, newValue) => component.Camera.PerspectiveFovY = MathHelper.ToRadians(newValue));
				
				ImGui.PropertyTableStartNewProperty("Near");
				HistorizeContinuousEdit<CameraComponent, float>(entity,
					currentValue: camera.PerspectiveNearPlane,
					showWidget: scope (value) => ImGui.DragFloat("##Near", &value, 0.1f, format: "%.3g"),
					applyValue: (entity, component, newValue) => component.Camera.PerspectiveNearPlane = newValue);
				
				ImGui.PropertyTableStartNewProperty("Far");
				HistorizeContinuousEdit<CameraComponent, float>(entity,
					currentValue: camera.PerspectiveFarPlane,
					showWidget: scope (value) => ImGui.DragFloat("##Far", &value, 0.1f, format: "%.3g"),
					applyValue: (entity, component, newValue) => component.Camera.PerspectiveFarPlane = newValue);
			}
			else if (camera.ProjectionType == .InfinitePerspective)
			{
				ImGui.PropertyTableStartNewProperty("Vertical FOV");
				HistorizeContinuousEdit<CameraComponent, float>(entity,
					currentValue: MathHelper.ToDegrees(camera.PerspectiveFovY),
					showWidget: scope (value) => ImGui.DragFloat("##Vertical FOV", &value, 0.1f, format: "%.3g°"),
					applyValue: (entity, component, newValue) => component.Camera.PerspectiveFovY = MathHelper.ToRadians(newValue));

				ImGui.PropertyTableStartNewProperty("Near");
				HistorizeContinuousEdit<CameraComponent, float>(entity,
					currentValue: camera.PerspectiveNearPlane,
					showWidget: scope (value) => ImGui.DragFloat("##Near", &value, 0.1f, format: "%.3g"),
					applyValue: (entity, component, newValue) => component.Camera.PerspectiveNearPlane = newValue);
			}
			else if (camera.ProjectionType == .Orthographic)
			{
				ImGui.PropertyTableStartNewProperty("Size");
				HistorizeContinuousEdit<CameraComponent, float>(entity,
					currentValue: camera.OrthographicHeight,
					showWidget: scope (value) => ImGui.DragFloat("##Size", &value, 0.1f, format: "%.3g"),
					applyValue: (entity, component, newValue) => component.Camera.OrthographicHeight = newValue);

				ImGui.PropertyTableStartNewProperty("Near");
				HistorizeContinuousEdit<CameraComponent, float>(entity,
					currentValue: camera.OrthographicNearPlane,
					showWidget: scope (value) => ImGui.DragFloat("##Near", &value, 0.1f, format: "%.3g"),
					applyValue: (entity, component, newValue) => component.Camera.OrthographicNearPlane = newValue);

				ImGui.PropertyTableStartNewProperty("Far");
				HistorizeContinuousEdit<CameraComponent, float>(entity,
					currentValue: camera.OrthographicFarPlane,
					showWidget: scope (value) => ImGui.DragFloat("##Far", &value, 0.1f, format: "%.3g"),
					applyValue: (entity, component, newValue) => component.Camera.OrthographicFarPlane = newValue);
			}
			
			ImGui.PropertyTableStartNewProperty("Fixed Aspect Ratio");
			HistorizeEdit<CameraComponent, bool>(entity,
				currentValue: camera.FixedAspectRatio,
				showWidget: scope (value) => ImGui.Checkbox("##Fixed Aspect Ratio", &value),
				applyValue: (entity, component, newValue) => component.Camera.FixedAspectRatio = newValue);

			if (camera.FixedAspectRatio)
			{
				ImGui.PropertyTableStartNewProperty("Aspect Ratio");
				HistorizeContinuousEdit<CameraComponent, float>(entity,
					currentValue: camera.AspectRatio,
					showWidget: scope (value) => ImGui.DragFloat("##Aspect Ratio", &value, 0.1f, format: "%.3g"),
					applyValue: (entity, component, newValue) => component.Camera.AspectRatio = newValue);
			}
		}

		private static void ShowSpriteRendererComponentEditor(Entity entity, SpriteRendererComponent* spriteRendererComponent)
		{
			ImGui.PropertyTableStartNewProperty("Color");
			HistorizeContinuousEdit<SpriteRendererComponent, ColorRGBA>(entity,
				currentValue: ColorRGBA.LinearToSRGB(spriteRendererComponent.Color),
				showWidget: scope (value) => ImGui.ColorEdit4("##Color", ref value),
				applyValue: (entity, component, newValue) => component.Color = ColorRGBA.SRgbToLinear(newValue));
			
			ImGui.PropertyTableStartNewProperty("Texture");
			HistorizeEdit<SpriteRendererComponent, AssetHandle>(entity,
				currentValue: spriteRendererComponent.Sprite,
				showWidget: scope (value) => ShowAssetDropTarget(ref value),
				applyValue: (entity, component, newValue) => component.Sprite = newValue);

			ImGui.PropertyTableStartNewProperty("UV Transform");
			HistorizeContinuousEdit<SpriteRendererComponent, float4>(entity,
				currentValue: spriteRendererComponent.UvTransform,
				showWidget: scope (value) => ImGui.Float4Editor("##UV Transform", ref value, resetValues: float4(0, 0, 1, 1)),
				applyValue: (entity, component, newValue) => component.UvTransform = newValue);

			ImGui.PropertyTableStartNewProperty("Material");
			HistorizeEdit<SpriteRendererComponent, AssetHandle<Material>>(entity,
				currentValue: spriteRendererComponent.Material,
				showWidget: scope (value) => ShowAssetDropTarget(ref value),
				applyValue: (entity, component, newValue) => component.Material = newValue);
		}
		
		public static bool ShowAssetDropTarget(ref AssetHandle target)
		{
			bool changed = false;

			Asset currentAsset = Content.GetAsset(target);

			StringView identifier = currentAsset?.Identifier ?? (target.IsValid ? "<Missing Asset>" : "None");

			if (ImGui.Button(identifier.ToScopeCStr!()))
			{
				// TODO: Show asset selector
			}

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.ContentBrowserItem);

				if (payload != null)
				{
					Log.EngineLogger.Warning("");

					// We shouldn't pass the path/identifier. We should carry ID and Type!
					StringView path = .((char8*)payload.Data, (int)payload.DataSize);

					// TODO: Somehow validate the type, please!
					target = (AssetHandle)Content.LoadAsset(path);
					changed = true;
				}

				ImGui.EndDragDropTarget();
			}

			return changed;
		}

		public static bool ShowAssetDropTarget<T>(ref AssetHandle<T> target) where T : Asset
		{
			bool changed = false;

			T currentAsset = target.Get();

			StringView identifier = (target.IsValid ? "<Missing Asset>" : "None");

			if (currentAsset != null)
				identifier = currentAsset.Identifier;
			
			if (ImGui.Button(identifier.ToScopeCStr!()))
			{
				// TODO: Show asset selector
			}

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.ContentBrowserItem);

				if (payload != null)
				{
					Log.EngineLogger.Warning("");

					StringView path = .((char8*)payload.Data, (int)payload.DataSize);

					// TODO: Somehow validate the type, please!
					target = (AssetHandle<T>)Content.LoadAsset(path);
					changed = true;
				}

				ImGui.EndDragDropTarget();
			}

			return changed;
		}

		/*private static void ShowCircleRendererComponentEditor(Entity entity, CircleRendererComponent* circleRendererComponent)
		{
			ColorRGBA spriteColor = ColorRGBA.LinearToSRGB(circleRendererComponent.Color);
			ImGui.PropertyTableStartNewProperty("Color");
			if (ImGui.ColorEdit4("##Color", ref spriteColor))
				circleRendererComponent.Color = ColorRGBA.SRgbToLinear(spriteColor);
			
			ImGui.PropertyTableStartNewProperty("Texture");
			ImGui.Button("...");

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.ContentBrowserItem);

				if (payload != null)
				{
					Log.EngineLogger.Warning("");

					StringView path = .((char8*)payload.Data, (int)payload.DataSize);

					circleRendererComponent.Sprite = Content.LoadAsset(path);
				}

				ImGui.EndDragDropTarget();
			}

			ImGui.PropertyTableStartNewProperty("UV Transform");
			ImGui.Float4Editor("##UV Transform", ref circleRendererComponent.UvTransform, resetValues: float4(0, 0, 1, 1));
			
			ImGui.PropertyTableStartNewProperty("Inner Radius");
			ImGui.DragFloat("##Inner Radius", &circleRendererComponent.InnerRadius, 0.1f, 0.0f, 1.0f, format: "%.3g");
		}*/

		private static void ShowTextRendererComponentEditor(Entity entity, TextRendererComponent* textRendererComponent)
		{
			ImGui.PropertyTableStartNewProperty("Rich text");

			ImGui.AttachTooltip("If checked, the text will be interpreted as rich text.");

			HistorizeEdit<TextRendererComponent, bool>(entity,
				currentValue: textRendererComponent.IsRichText,
				showWidget: scope (value) => ImGui.Checkbox("##rich_text", &value),
				applyValue: (entity, component, newValue) => {
						component.IsRichText = newValue;
						component.NeedsRebuild = true;
					});

			String buffer = new:ScopedAlloc! String(textRendererComponent.Text);
			ImGui.PropertyTableStartNewProperty("Text");
			HistorizeContinuousEdit<TextRendererComponent, String>(entity,
				currentValue: buffer,
				showWidget: scope (value) => ImGui.InputTextMultiline("##text", value),
				applyValue: (entity, component, newValue) => {
						component.Text = newValue;
						component.NeedsRebuild = true;
					});

			ImGui.PropertyTableStartNewProperty("Font Size");
			HistorizeContinuousEdit<TextRendererComponent, float>(entity,
				currentValue: textRendererComponent.[Friend]FontSize,
				showWidget: scope (value) => ImGui.DragFloat("##fontSize", &value, format: "%.3g"),
				applyValue: (entity, component, newValue) => {
						component.FontSize = newValue;
						component.NeedsRebuild = true;
					});

			ImGui.PropertyTableStartNewProperty("Color");
			HistorizeContinuousEdit<TextRendererComponent, ColorRGBA>(entity,
				currentValue: textRendererComponent.Color,
				showWidget: scope (value) => ImGui.ColorEdit4("##color", ref value),
				applyValue: (entity, component, newValue) => {
						component.Color = newValue;
						component.NeedsRebuild = true;
					});

			HistorizeEdit<TextRendererComponent, FontRenderer.HorizontalTextAlignment>(entity,
				currentValue: textRendererComponent.HorizontalAlignment,
				showWidget: scope (value) => ImGui.EnumCombo("##horAlign", ref value),
				applyValue: (entity, component, newValue) => {
						component.HorizontalAlignment = newValue;
						component.NeedsRebuild = true;
					});
		}

		private static void ShowMeshRendererComponentEditor(Entity entity, MeshRendererComponent* meshRendererComponent)
		{
			ImGui.PropertyTableStartNewProperty("Material");
			HistorizeEdit<MeshRendererComponent, AssetHandle<Material>>(entity,
				currentValue: meshRendererComponent.Material,
				showWidget: scope (value) => ShowAssetDropTarget(ref value),
				applyValue: (entity, component, newValue) => component.Material = newValue);
		}
		
		private static void ShowRigidBody2DComponentEditor(Entity entity, Rigidbody2DComponent* rigidBodyComponent)
		{
			ImGui.PropertyTableStartNewProperty("Type");
			HistorizeEdit<Rigidbody2DComponent, Rigidbody2DComponent.BodyType>(entity,
				currentValue: rigidBodyComponent.BodyType,
				showWidget: scope (value) => ImGui.EnumCombo("##Type", ref value),
				applyValue: (entity, component, newValue) => component.BodyType = newValue
			);

			ImGui.PropertyTableStartNewProperty("Fixed Rotation");
			HistorizeEdit<Rigidbody2DComponent, bool>(entity,
				currentValue: rigidBodyComponent.FixedRotation,
				showWidget: scope (value) => ImGui.Checkbox("##Fixed Rotation", &value),
				applyValue: (entity, component, newValue) => component.FixedRotation = newValue
			);

			ImGui.PropertyTableStartNewProperty("Fixed Rotation");
			HistorizeContinuousEdit<Rigidbody2DComponent, float>(entity,
				currentValue: rigidBodyComponent.GravityScale,
				showWidget: scope (value) => ImGui.DragFloat("##Gravity Scale", &value, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.GravityScale = newValue
			);
		}

		private static void ShowBoxCollider2DComponentEditor(Entity entity, BoxCollider2DComponent* boxCollider)
		{
			ImGui.PropertyTableStartNewProperty("Offset");
			HistorizeContinuousEdit<BoxCollider2DComponent, float2>(entity,
				currentValue: boxCollider.Offset,
				showWidget: scope (value) => ImGui.Float2Editor("##Offset", ref value, .Zero, 0.1f),
				applyValue: (entity, component, newValue) => component.Offset = newValue
			);
			
			ImGui.PropertyTableStartNewProperty("Offset");
			HistorizeContinuousEdit<BoxCollider2DComponent, float2>(entity,
				currentValue: boxCollider.Size,
				showWidget: scope (value) => ImGui.Float2Editor("##Size", ref value, .Zero, 0.1f, float2(0.01f, 0.01f), float.PositiveInfinity.XX),
				applyValue: (entity, component, newValue) => component.Size = newValue
			);

			ImGui.PropertyTableStartNewProperty("Density");
			HistorizeContinuousEdit<BoxCollider2DComponent, float>(entity,
				currentValue: boxCollider.Density,
				showWidget: scope (value) => ImGui.DragFloat("##Density", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.Density = newValue
			);
			
			ImGui.PropertyTableStartNewProperty("Friction");
			HistorizeContinuousEdit<BoxCollider2DComponent, float>(entity,
				currentValue: boxCollider.Friction,
				showWidget: scope (value) => ImGui.DragFloat("##Friction", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.Friction = newValue
			);

			ImGui.PropertyTableStartNewProperty("Restitution");
			HistorizeContinuousEdit<BoxCollider2DComponent, float>(entity,
				currentValue: boxCollider.Restitution,
				showWidget: scope (value) => ImGui.DragFloat("##Restitution", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.Restitution = newValue
			);

			ImGui.PropertyTableStartNewProperty("Restitution Threshold");
			HistorizeContinuousEdit<BoxCollider2DComponent, float>(entity,
				currentValue: boxCollider.RestitutionThreshold,
				showWidget: scope (value) => ImGui.DragFloat("##RestitutionThreshold", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.RestitutionThreshold = newValue
			);
		}

		private static void ShowCircleCollider2DComponentEditor(Entity entity, CircleCollider2DComponent* circleCollider)
		{
			ImGui.PropertyTableStartNewProperty("Offset");
			HistorizeContinuousEdit<CircleCollider2DComponent, float2>(entity,
				currentValue: circleCollider.Offset,
				showWidget: scope (value) => ImGui.Float2Editor("##Offset", ref value, .Zero, 0.1f),
				applyValue: (entity, component, newValue) => component.Offset = newValue
			);
			
			ImGui.PropertyTableStartNewProperty("Radius");
			HistorizeContinuousEdit<CircleCollider2DComponent, float>(entity,
				currentValue: circleCollider.Radius,
				showWidget: scope (value) => ImGui.DragFloat("##Radius", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.Radius = newValue
			);
			
			ImGui.PropertyTableStartNewProperty("Density");
			HistorizeContinuousEdit<CircleCollider2DComponent, float>(entity,
				currentValue: circleCollider.Density,
				showWidget: scope (value) => ImGui.DragFloat("##Density", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.Density = newValue
			);
			
			ImGui.PropertyTableStartNewProperty("Friction");
			HistorizeContinuousEdit<CircleCollider2DComponent, float>(entity,
				currentValue: circleCollider.Friction,
				showWidget: scope (value) => ImGui.DragFloat("##Friction", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.Friction = newValue
			);
			
			ImGui.PropertyTableStartNewProperty("Restitution");
			HistorizeContinuousEdit<CircleCollider2DComponent, float>(entity,
				currentValue: circleCollider.Restitution,
				showWidget: scope (value) => ImGui.DragFloat("##Restitution", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.Restitution = newValue
			);
			
			ImGui.PropertyTableStartNewProperty("Restitution Threshold");
			HistorizeContinuousEdit<CircleCollider2DComponent, float>(entity,
				currentValue: circleCollider.RestitutionThreshold,
				showWidget: scope (value) => ImGui.DragFloat("##RestitutionThreshold", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.RestitutionThreshold = newValue
			);
		}

		/// If true handles for editing the vertices of the PolygonCollider2DComponent will be visible 
		private static bool _editVerticesPolygonCollider2D = false;

		/// Shows a collapsing header in a separate table row.
		private static bool CollapsingHeader(StringView header)
		{
			ImGui.TableNextRow();
			ImGui.TableSetColumnIndex(0);

			return ImGui.CollapsingHeader("Vertices", .SpanAllColumns);
		}

		private static void ShowPolygonCollider2DComponentEditor(Entity entity, PolygonCollider2DComponent* polygonCollider)
		{
			ImGui.PropertyTableStartNewProperty("Offset");
			HistorizeContinuousEdit<PolygonCollider2DComponent, float2>(entity,
				currentValue: polygonCollider.Offset,
				showWidget: scope (value) => ImGui.Float2Editor("##Offset", ref value, .Zero, 0.1f),
				applyValue: (entity, component, newValue) => component.Offset = newValue
			);

			ImGui.PropertyTableStartNewRow();

			bool isOpen = ImGui.TreeNodeEx("Vertices", .AllowOverlap | .SpanAllColumns);

			ImGui.TableSetColumnIndex(1);

			var addButtonWidth = ImGui.CalcTextSize("+").x + 2 * ImGui.GetStyle().FramePadding.x;
			var removeButtonWidth = ImGui.CalcTextSize("-").x + 2 * ImGui.GetStyle().FramePadding.x;
			
			ImGui.SameLine(ImGui.GetContentRegionAvail().x - addButtonWidth - ImGui.GetStyle().FramePadding.x - removeButtonWidth);
			
			ImGui.BeginDisabled(polygonCollider.VertexCount >= 8);
			
			HistorizeEdit<PolygonCollider2DComponent, int8>(entity,
				currentValue: polygonCollider.VertexCount,
				showWidget: scope (value) => {
					if (ImGui.SmallButton("+"))
					{
						value++;
						return true;
					}
					return false;
				},
				applyValue: (entity, component, newValue) => component.VertexCount = newValue
			);

			ImGui.AttachTooltip("Add a new vertex to the collider.");

			ImGui.EndDisabled();

			ImGui.SameLine(ImGui.GetContentRegionAvail().x - removeButtonWidth);

			ImGui.BeginDisabled(polygonCollider.VertexCount <= 3);

			HistorizeEdit<PolygonCollider2DComponent, int8>(entity,
				currentValue: polygonCollider.VertexCount,
				showWidget: scope (value) => {
					if (ImGui.SmallButton("-"))
					{
						value--;
						return true;
					}
					return false;
				},
				applyValue: (entity, component, newValue) => component.VertexCount = newValue
			);

			ImGui.AttachTooltip("Remove the last vertex from the collider.");

			ImGui.EndDisabled();

			if (isOpen)
			{
				ImGui.PropertyTableStartNewProperty("Show Vertex gizmos");
				ImGui.Checkbox("##Show Vertex gizmos", &_editVerticesPolygonCollider2D);

				for (int i < polygonCollider.VertexCount)
				{
					ImGui.PropertyTableStartNewProperty(scope $"{i}");

					// applyValue is a function pointer and can't capture values.
					// However we need the polygon-index -> capture it inside value tuple (index, value)
					HistorizeContinuousEdit<PolygonCollider2DComponent, (int Index, float2 Value)>(entity,
						currentValue: (i, polygonCollider.Vertices[i]),
						showWidget: scope (value) => ImGui.Float2Editor(scope $"##{i}", ref value.Value),
						applyValue: (entity, component, newValue) => component.Vertices[newValue.Index] = newValue.Value
					);
				}

				ImGui.TreePop();
			}

			ImGui.PropertyTableStartNewProperty("Density");
			HistorizeContinuousEdit<PolygonCollider2DComponent, float>(entity,
				currentValue: polygonCollider.Density,
				showWidget: scope (value) => ImGui.DragFloat("##Density", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.Density = newValue
			);

			ImGui.PropertyTableStartNewProperty("Friction");
			HistorizeContinuousEdit<PolygonCollider2DComponent, float>(entity,
				currentValue: polygonCollider.Friction,
				showWidget: scope (value) => ImGui.DragFloat("##Friction", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.Friction = newValue
			);

			ImGui.PropertyTableStartNewProperty("Restitution");
			HistorizeContinuousEdit<PolygonCollider2DComponent, float>(entity,
				currentValue: polygonCollider.Restitution,
				showWidget: scope (value) => ImGui.DragFloat("##Restitution", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.Restitution = newValue
			);

			ImGui.PropertyTableStartNewProperty("Restitution Threshold");
			HistorizeContinuousEdit<PolygonCollider2DComponent, float>(entity,
				currentValue: polygonCollider.RestitutionThreshold,
				showWidget: scope (value) => ImGui.DragFloat("##RestitutionThreshold", &value, 0.0f, 0.1f, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.RestitutionThreshold = newValue
			);
		}
		
		static String search = new .(64) ~ delete _;
		private static void ShowScriptComponentEditor(Entity entity, ScriptComponent* scriptComponent)
		{
			char8* scriptLabel = scriptComponent.ScriptClassName.ToScopeCStr!() ?? "Select Script...";
			
			ImGui.PropertyTableStartNewProperty("Script");
			if (ImGui.Button(scriptLabel))
				ImGui.OpenPopup("SelectScript");

			if (ImGui.BeginPopup("SelectScript"))
			{
				ImGui.InputText("##ScriptSearch", search);

				for (let (className, scriptClass) in ScriptEngine.EntityClasses)
				{
					if (!search.IsWhiteSpace && !className.Contains(search, true))
						continue;

					if (ImGui.Selectable(className.ToScopeCStr!(),
						className == scriptComponent.ScriptClassName))
					{
						var command = new ChangeComponentPropertyCommand<ScriptComponent, String>(ImGui.GetItemID(),
							entity.Scene, entity.UUID,
							newValue: scriptClass.FullName, oldValue: scriptComponent.ScriptClassName,
							applyValue: (entity, component, newValue) => {
								component.ScriptClassName = newValue;
								// TODO: This currently does nothing useful, because we don't create new instances,
								// also when we implement creating the appropriate script instance, we must somehow retain the old one.
							});
						Editor.Instance.HistoryManager.Do(command);
					}
				}
				ImGui.EndPopup();
			}

			ScriptEngine.ShowScriptEditor(entity, scriptComponent);
		}

		private static void ShowLightComponentEditor(Entity entity, LightComponent* lightComponent)
		{
			ImGui.PropertyTableStartNewProperty("Type");
			HistorizeContinuousEdit<LightComponent, SceneLight.LightType>(entity,
				currentValue: lightComponent.SceneLight.LightType,
				showWidget: scope (value) => ImGui.EnumCombo("##Type", ref value),
				applyValue: (entity, component, newValue) => component.SceneLight.LightType = newValue
			);
			
			ImGui.PropertyTableStartNewProperty("Color");
			HistorizeContinuousEdit<LightComponent, ColorRGB>(entity,
				currentValue: ColorRGB.LinearToSRGB(lightComponent.SceneLight.Color),
				showWidget: scope (value) => ImGui.ColorEdit3("##Color", ref value),
				applyValue: (entity, component, newValue) => component.SceneLight.Color = ColorRGB.SRgbToLinear(newValue)
			);

			ImGui.PropertyTableStartNewProperty("Illuminance");
			HistorizeContinuousEdit<LightComponent, float>(entity,
				currentValue: lightComponent.SceneLight.Illuminance,
				showWidget: scope (value) => ImGui.DragFloat("##Illuminance", &value, 0.1f, 0.0f, float.MaxValue, format: "%.3g"),
				applyValue: (entity, component, newValue) => component.SceneLight.Illuminance = newValue
			);
		}

		private static void ShowMeshComponentEditor(Entity entity, MeshComponent* meshComponent)
		{
			ImGui.PropertyTableStartNewProperty("Mesh");
			HistorizeEdit<MeshComponent, AssetHandle<GeometryBinding>>(entity,
				currentValue: meshComponent.Mesh,
				showWidget: scope (value) => ShowAssetDropTarget<GeometryBinding>(ref value),
				applyValue: (entity, component, newValue) => component.Mesh = newValue
			);
		}

		private static void ShowAddComponentButton(Entity entity)
		{
			static char8[128] searchBuffer = .();
			static StringView searchFilter = .();
			
			static float buttonWidth = 100;

			ImGui.Separator();
			ImGui.NewLine();

			void ShowComponentButton<TComponent>(String name) where TComponent : struct, new
			{
				// If the entity already has this component, don't show the option to add it
				if (entity.HasComponent<TComponent>())
					return;

				float textWidth = ImGui.CalcTextSize(name.CStr()).x;
				buttonWidth = Math.Max(buttonWidth, textWidth + ImGui.GetStyle().FramePadding.x * 2);

				if (name.Contains(searchFilter, true) && ImGui.Selectable(name))
				{
					if (!entity.HasComponent<TComponent>())
					{
						Editor.Instance.HistoryManager.Do(new AddComponentCommand<TComponent>(entity.Scene, entity.UUID));
					}
				}
			}

			float textWidth = ImGui.CalcTextSize("Add Component...").x;
			buttonWidth = Math.Max(buttonWidth, textWidth + ImGui.GetStyle().FramePadding.x * 2);

			ImGui.PushItemWidth(buttonWidth);

			ImGui.NewLine();
			ImGui.SameLine(ImGui.GetContentRegionMax().x / 2 - buttonWidth / 2);

			if (ImGui.BeginCombo("##add_component_combo", "Add Component...", .NoArrowButton))
			{
				if (ImGui.InputText("##search_component_name", &searchBuffer, (.)searchBuffer.Count))
				{
					searchFilter = .(&searchBuffer);
				}

				ImGui.Separator();

				ShowComponentButton<CameraComponent>("Camera");
				ShowComponentButton<SpriteRendererComponent>("Sprite Renderer");
				ShowComponentButton<CircleRendererComponent>("Circle Renderer");
				ShowComponentButton<TextRendererComponent>("Text Renderer");
				ShowComponentButton<LightComponent>("Light");
				ShowComponentButton<Rigidbody2DComponent>("Rigidbody 2D");
				ShowComponentButton<BoxCollider2DComponent>("Box collider 2D");
				//ShowComponentButton<CircleCollider2DComponent>("Circle collider 2D");
				ShowComponentButton<PolygonCollider2DComponent>("Polygon collider 2D");
				ShowComponentButton<MeshComponent>("Mesh");
				ShowComponentButton<MeshRendererComponent>("Mesh Renderer");
				ShowComponentButton<ScriptComponent>("C# Script");

				ImGui.EndCombo();
			}

			ImGui.PopItemWidth();
		}
	}
}

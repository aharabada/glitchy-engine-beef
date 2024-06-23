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
using Mono;
using GlitchyEngine.World.Components;

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
			ShowComponentEditor<CircleRendererComponent>(componentType, "Circle Renderer", entity, => ShowCircleRendererComponentEditor, => ShowComponentContextMenu<CircleRendererComponent>);
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
				for (int i < collider.VertexCount)
				{
					Matrix localToWorld = entity.Transform.WorldTransform * Matrix.Translation(collider.Offset.X, collider.Offset.Y, 0);
					Matrix transform = Matrix.Translation(float3(collider.Vertices[i], 0)) * localToWorld;
	
					if (Handles.ShowGizmo(ref transform, .TRANSLATE_X | .TRANSLATE_Y, true, id: (int32)i))
					{
						transform = localToWorld.Invert() * transform;
	
						collider.Vertices[i] = transform.Translation.XY;
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
			if (ImGui.Selectable("Remove Component"))
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
			
			ImGui.PushStyleColor(.Button, .(0, 0, 0, 0));

			if (showComponentContextMenu != null)
			{
				positionX -= buttonSize.X + ImGui.GetStyle().FramePadding.x;
				ImGui.SameLine(positionX);
				positionX -= ImGui.GetStyle().FramePadding.x;

				if (ImGui.ImageButton("save", EditorIcons.Instance.Icon_ContextMenu, (.)buttonSize))
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

				if (ImGui.ImageButton("save", EditorIcons.Instance.Icon_Save, (.)buttonSize))
				{
					if (Entity editorEntity = Editor.Instance.EditorScene.GetEntityByID(entity.UUID))
					{
						Scene.CopyComponent<TComponent>(entity, editorEntity);

						if (typeof(TComponent) == typeof(ScriptComponent))
						{
							// TODO: Copy script data into editor
							// TODO: Somehow get the scriptserializer used to serialize the editor scene
							//scriptSerializer.SerializeScriptInstance(((ScriptComponent*)component).Instance);
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

		private static void ShowTransformComponentEditor(Entity entity, TransformComponent* transform)
		{
			float textWidth = ImGui.CalcTextSize("Position".CStr()).x;
			textWidth = Math.Max(textWidth, ImGui.CalcTextSize("Rotation".CStr()).x);
			textWidth = Math.Max(textWidth, ImGui.CalcTextSize("Scale".CStr()).x);

			textWidth += ImGui.GetStyle().FramePadding.x * 3.0f;

			float3 position = transform.Position;

			ImGui.PropertyTableStartNewProperty("Position");
			if (ImGui.Float3Editor("##Position", ref position, resetValues: .Zero, dragSpeed: 0.1f))
			{
				transform.Position = position;

				// if necessary reposition Rigidbody2D
				if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
				{
					rigidbody2D.SetPosition(position.XY);
				}
			}

			float3 rotationEuler = MathHelper.ToDegrees(transform.EditorRotationEuler);

			bool3 componentEditable = true;

			if (entity.HasComponent<Rigidbody2DComponent>())
			{
				// Disable X and Y rotation for 2D rigid bodies
				componentEditable.XY = false;
				rotationEuler.XY = 0;
			}
			
			ImGui.PropertyTableStartNewProperty("Rotation");
			if (ImGui.Float3Editor("##Rotation", ref rotationEuler, resetValues: .Zero, dragSpeed: 0.1f, componentEnabled: componentEditable, format: .("%.3g°",)))
			{
				transform.EditorRotationEuler = MathHelper.ToRadians(rotationEuler);
				
				// if necessary reposition Rigidbody2D
				if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
				{
					rigidbody2D.SetAngle(rotationEuler.Z);
				}
			}
			
			float3 scale = transform.Scale;

			ImGui.PropertyTableStartNewProperty("Scale");
			if (ImGui.Float3Editor("##Scale", ref scale, resetValues: .One, dragSpeed: 0.1f))
				transform.Scale = scale;
		}
		
		static String[] strings = new String[]("Orthographic", "Perspective", "Perspective (Infinite)") ~ delete _;

		private static void ShowCameraComponentEditor(Entity entity, CameraComponent* cameraComponent)
		{
			ImGui.PropertyTableStartNewProperty("Is Primary");
			ImGui.Checkbox("##Is_Primary", &cameraComponent.Primary);

			var camera = ref cameraComponent.Camera;

			String typeName = strings[camera.ProjectionType.Underlying];
			
			ImGui.PropertyTableStartNewProperty("Projection");
			if (ImGui.BeginCombo("##Projection", typeName.CStr()))
			{
				for (int i = 0; i < 3; i++)
				{
					bool isSelected = (typeName == strings[i]);

					if (ImGui.Selectable(strings[i], isSelected))
					{
						camera.ProjectionType = (.)i;
					}

					if (isSelected)
						ImGui.SetItemDefaultFocus();
				}

				ImGui.EndCombo();
			}

			if (camera.ProjectionType == .Perspective)
			{
				ImGui.PropertyTableStartNewProperty("Fov Y");
				float fovY = MathHelper.ToDegrees(camera.PerspectiveFovY);
				if (ImGui.DragFloat("##Fov Y", &fovY, 0.1f, format: "%.3g°"))
					camera.PerspectiveFovY = MathHelper.ToRadians(fovY);
				
				ImGui.PropertyTableStartNewProperty("Near");
				float near = camera.PerspectiveNearPlane;
				if (ImGui.DragFloat("##Near", &near, 0.1f, format: "%.3g"))
					camera.PerspectiveNearPlane = near;
				
				ImGui.PropertyTableStartNewProperty("Far");
				float far = camera.PerspectiveFarPlane;
				if (ImGui.DragFloat("##Far", &far, 0.1f, format: "%.3g"))
					camera.PerspectiveFarPlane = far;
			}
			else if (camera.ProjectionType == .InfinitePerspective)
			{
				ImGui.PropertyTableStartNewProperty("Vertical FOV");
				float fovY = MathHelper.ToDegrees(camera.PerspectiveFovY);
				if (ImGui.DragFloat("##Vertical FOV", &fovY, 0.1f, format: "%.3g°"))
					camera.PerspectiveFovY = MathHelper.ToRadians(fovY);
				
				ImGui.PropertyTableStartNewProperty("Near");
				float near = camera.PerspectiveNearPlane;
				if (ImGui.DragFloat("##Near", &near, 0.1f, format: "%.3g"))
					camera.PerspectiveNearPlane = near;
			}
			else if (camera.ProjectionType == .Orthographic)
			{
				ImGui.PropertyTableStartNewProperty("Size");
				float size = camera.OrthographicHeight;
				if (ImGui.DragFloat("##Size", &size, 0.1f, format: "%.3g"))
					camera.OrthographicHeight = size;
				
				ImGui.PropertyTableStartNewProperty("Near");
				float near = camera.OrthographicNearPlane;
				if (ImGui.DragFloat("##Near", &near, 0.1f, format: "%.3g"))
					camera.OrthographicNearPlane = near;
				
				ImGui.PropertyTableStartNewProperty("Far");
				float far = camera.OrthographicFarPlane;
				if (ImGui.DragFloat("##Far", &far, 0.1f, format: "%.3g"))
					camera.OrthographicFarPlane = far;
			}
			
			ImGui.PropertyTableStartNewProperty("Fixed Aspect Ratio");
			bool fixedAspectRatio = camera.FixedAspectRatio;
			if (ImGui.Checkbox("##Fixed Aspect Ratio", &fixedAspectRatio))
				camera.FixedAspectRatio = fixedAspectRatio;

			if (fixedAspectRatio)
			{
				ImGui.PropertyTableStartNewProperty("Aspect Ratio");
				float aspect = camera.AspectRatio;
				if (ImGui.DragFloat("##Aspect Ratio", &aspect, 0.1f, format: "%.3g"))
					camera.AspectRatio = aspect;
			}
		}

		private static void ShowSpriteRendererComponentEditor(Entity entity, SpriteRendererComponent* spriteRendererComponent)
		{
			ColorRGBA spriteColor = ColorRGBA.LinearToSRGB(spriteRendererComponent.Color);
			ImGui.PropertyTableStartNewProperty("Color");
			if (ImGui.ColorEdit4("##Color", ref spriteColor))
				spriteRendererComponent.Color = ColorRGBA.SRgbToLinear(spriteColor);
			
			ImGui.PropertyTableStartNewProperty("Texture");
			ImGui.Button("...");

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.ContentBrowserItem);

				if (payload != null)
				{
					Log.EngineLogger.Warning("");

					StringView path = .((char8*)payload.Data, (int)payload.DataSize);

					spriteRendererComponent.Sprite = Content.LoadAsset(path);
				}

				ImGui.EndDragDropTarget();
			}

			ImGui.PropertyTableStartNewProperty("UV Transform");
			ImGui.Float4Editor("##UV Transform", ref spriteRendererComponent.UvTransform, resetValues: float4(0, 0, 1, 1));
		}

		private static void ShowCircleRendererComponentEditor(Entity entity, CircleRendererComponent* circleRendererComponent)
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
		}
		
		static int InputTextCallback(ImGui.InputTextCallbackData* data)
		{
			if (data.EventFlag == .CallbackResize)
			{
				String str = (String)Internal.UnsafeCastToObject(data.UserData);

				Log.EngineLogger.AssertDebug(str.Ptr == data.Buf);

				str.PadRight(data.BufTextLen * 2, '\0');
				data.Buf = str.Ptr;

				return 0;
			}

			return 0;
		}

		private static void ShowTextRendererComponentEditor(Entity entity, TextRendererComponent* textRendererComponent)
		{
			ImGui.PropertyTableStartNewProperty("Rich text");

			ImGui.AttachTooltip("If checked, the text will be interpreted as rich text.");

			bool isRichText = textRendererComponent.IsRichText;

			if (ImGui.Checkbox("##rich_text", &isRichText))
			{
				textRendererComponent.IsRichText = isRichText;
				textRendererComponent.NeedsRebuild = true;
			}

			ImGui.PropertyTableStartNewProperty("Text");

			String text = textRendererComponent.[Friend]_text;

			if (text == null)
			{
				text = textRendererComponent.[Friend]_text = new String();
			}

			text?.EnsureNullTerminator();

			if (ImGui.InputTextMultiline("##text", text.CStr(), (uint64)(text.Length + 1), .Zero, .CallbackResize, => InputTextCallback, Internal.UnsafeCastToPtr(text)))
			{
				// To deleting text, ImGui simply puts a null char after the remaining text.
				// Search for null char and set the length of the string accordingly.
				int length = text.IndexOf('\0');

				if (length >= 0)
				{
					text.Length = length;
				}
				
				textRendererComponent.NeedsRebuild = true;
			}

			ImGui.PropertyTableStartNewProperty("Font Size");

			if (ImGui.DragFloat("##fontSize", &textRendererComponent.FontSize, format: "%.3g"))
			{
				textRendererComponent.NeedsRebuild = true;
			}

			ImGui.PropertyTableStartNewProperty("Color");

			if (ImGui.ColorEdit4("##color", ref textRendererComponent.Color))
			{
				textRendererComponent.NeedsRebuild = true;
			}

			ImGui.PropertyTableStartNewProperty("Horizontal Alignment");

			if (ImGui.EnumCombo("##horAlign", ref textRendererComponent.HorizontalAlignment))
			{
				textRendererComponent.NeedsRebuild = true;
			}
		}

		private static void ShowMeshRendererComponentEditor(Entity entity, MeshRendererComponent* meshRendererComponent)
		{
			ImGui.PropertyTableStartNewProperty("Material");
			
			Material material = meshRendererComponent.Material;

			StringView identifier = material?.Identifier ?? "None";
			ImGui.Button(identifier.ToScopeCStr!());

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.ContentBrowserItem);

				if (payload != null)
				{
					StringView fullpath = .((char8*)payload.Data, (int)payload.DataSize);

					meshRendererComponent.Material = Content.LoadAsset(fullpath);
				}

				ImGui.EndDragDropTarget();
			}

			/*Effect effect = material?.Effect;

			if (effect == null)
				return;*/

			// Show a preview of the material here!
		}
		
		private static void ShowRigidBody2DComponentEditor(Entity entity, Rigidbody2DComponent* rigidBodyComponent)
		{
			const String[?] bodyTypeStrings = .("Static", "Dynamic", "Kinematic");
			String bodyTypeName = bodyTypeStrings[rigidBodyComponent.BodyType.Underlying];
			
			ImGui.PropertyTableStartNewProperty("Type");
			if (ImGui.BeginCombo("##Type", bodyTypeName.CStr()))
			{
				for (int i = 0; i < 3; i++)
				{
					bool isSelected = (bodyTypeName == bodyTypeStrings[i]);

					if (ImGui.Selectable(bodyTypeStrings[i], isSelected))
					{
						rigidBodyComponent.BodyType = (.)i;
					}

					if (isSelected)
						ImGui.SetItemDefaultFocus();
				}

				ImGui.EndCombo();
			}

			bool isFixedRotation = rigidBodyComponent.FixedRotation;
			ImGui.PropertyTableStartNewProperty("Fixed Rotation");
			if (ImGui.Checkbox("##Fixed Rotation", &isFixedRotation))
			{
				rigidBodyComponent.FixedRotation = isFixedRotation;
			}

			float gravityScale = rigidBodyComponent.GravityScale;
			ImGui.PropertyTableStartNewProperty("Gravity Scale");
			if (ImGui.DragFloat("##Gravity Scale", &gravityScale, format: "%.3g"))
			{
				rigidBodyComponent.GravityScale = gravityScale;
			}
		}

		private static void ShowBoxCollider2DComponentEditor(Entity entity, BoxCollider2DComponent* boxCollider)
		{
			float2 offset = boxCollider.Offset;
			ImGui.PropertyTableStartNewProperty("Offset");
			if (ImGui.Float2Editor("##Offset", ref offset, .Zero, 0.1f))
				boxCollider.Offset = offset;

			float2 size = boxCollider.Size;
			ImGui.PropertyTableStartNewProperty("Size");
			if (ImGui.Float2Editor("##Size", ref size, .Zero, 0.1f, float2(0.01f, 0.01f), float.PositiveInfinity.XX))
				boxCollider.Size = size;
			
			float density = boxCollider.Density;
			ImGui.PropertyTableStartNewProperty("Density");
			if (ImGui.DragFloat("##Density", &density, 0.0f, 0.1f, format: "%.3g"))
				boxCollider.Density = density;
			
			float friction = boxCollider.Friction;
			ImGui.PropertyTableStartNewProperty("Friction");
			if (ImGui.DragFloat("##Friction", &friction, 0.0f, 0.1f, format: "%.3g"))
				boxCollider.Friction = friction;

			float restitution = boxCollider.Restitution;
			ImGui.PropertyTableStartNewProperty("Restitution");
			if (ImGui.DragFloat("##Restitution", &restitution, 0.0f, 0.1f, format: "%.3g"))
				boxCollider.Restitution = restitution;

			float restitutionThreshold = boxCollider.RestitutionThreshold;
			ImGui.PropertyTableStartNewProperty("Restitution Threshold");
			if (ImGui.DragFloat("##RestitutionThreshold", &restitutionThreshold, 0.0f, 0.1f, format: "%.3g"))
				boxCollider.RestitutionThreshold = restitutionThreshold;
		}

		private static void ShowCircleCollider2DComponentEditor(Entity entity, CircleCollider2DComponent* circleCollider)
		{
			float2 offset = circleCollider.Offset;
			ImGui.PropertyTableStartNewProperty("Offset");
			if (ImGui.Float2Editor("##Offset", ref offset, .Zero, 0.1f))
				circleCollider.Offset = offset;

			float radius = circleCollider.Radius;
			ImGui.PropertyTableStartNewProperty("Radius");
			if (ImGui.DragFloat("##Radius", &radius, 0.0f, 0.1f, format: "%.3g"))
				circleCollider.Radius = radius;
			
			float density = circleCollider.Density;
			ImGui.PropertyTableStartNewProperty("Density");
			if (ImGui.DragFloat("##Density", &density, 0.0f, 0.1f, format: "%.3g"))
				circleCollider.Density = density;
			
			float friction = circleCollider.Friction;
			ImGui.PropertyTableStartNewProperty("Friction");
			if (ImGui.DragFloat("##Friction", &friction, 0.0f, 0.1f, format: "%.3g"))
				circleCollider.Friction = friction;

			float restitution = circleCollider.Restitution;
			ImGui.PropertyTableStartNewProperty("Restitution");
			if (ImGui.DragFloat("##Restitution", &restitution, 0.0f, 0.1f, format: "%.3g"))
				circleCollider.Restitution = restitution;

			float restitutionThreshold = circleCollider.RestitutionThreshold;
			ImGui.PropertyTableStartNewProperty("Restitution Threshold");
			if (ImGui.DragFloat("##RestitutionThreshold", &restitutionThreshold, 0.0f, 0.1f, format: "%.3g"))
				circleCollider.RestitutionThreshold = restitutionThreshold;
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
			float2 offset = polygonCollider.Offset;
			ImGui.PropertyTableStartNewProperty("Offset");
			if (ImGui.Float2Editor("Offset", ref offset, .Zero, 0.1f))
				polygonCollider.Offset = offset;

			ImGui.PropertyTableStartNewRow();

			bool isOpen = ImGui.TreeNodeEx("Vertices", .AllowOverlap | .SpanAllColumns);

			ImGui.TableSetColumnIndex(1);

			var addButtonWidth = ImGui.CalcTextSize("+").x + 2 * ImGui.GetStyle().FramePadding.x;
			var removeButtonWidth = ImGui.CalcTextSize("-").x + 2 * ImGui.GetStyle().FramePadding.x;
			
			ImGui.SameLine(ImGui.GetContentRegionAvail().x - addButtonWidth - ImGui.GetStyle().FramePadding.x - removeButtonWidth);
			
			ImGui.BeginDisabled(polygonCollider.VertexCount >= 8);

			if (ImGui.SmallButton("+"))
				polygonCollider.VertexCount++;

			ImGui.AttachTooltip("Add a new vertex to the collider.");

			ImGui.EndDisabled();

			ImGui.SameLine(ImGui.GetContentRegionAvail().x - removeButtonWidth);

			ImGui.BeginDisabled(polygonCollider.VertexCount <= 3);

			if (ImGui.SmallButton("-"))
				polygonCollider.VertexCount--;

			ImGui.AttachTooltip("Remove the last vertex from the collider.");

			ImGui.EndDisabled();

			// If isOpen is true, show list of vertices
			if (isOpen)
			{
				ImGui.PropertyTableStartNewProperty("Show Vertex gizmos");
				ImGui.Checkbox("##Show Vertex gizmos", &_editVerticesPolygonCollider2D);

				for (int i < polygonCollider.VertexCount)
				{
					ImGui.PropertyTableStartNewProperty(scope $"{i}");
					ImGui.Float2Editor(scope $"##{i}", ref polygonCollider.Vertices[i]);
				}

				ImGui.TreePop();
			}

			float density = polygonCollider.Density;
			ImGui.PropertyTableStartNewProperty("Density");
			if (ImGui.DragFloat("##Density", &density, 0.0f, 0.1f, format: "%.3g"))
				polygonCollider.Density = density;
			
			float friction = polygonCollider.Friction;
			ImGui.PropertyTableStartNewProperty("Friction");
			if (ImGui.DragFloat("##Friction", &friction, 0.0f, 0.1f, format: "%.3g"))
				polygonCollider.Friction = friction;

			float restitution = polygonCollider.Restitution;
			ImGui.PropertyTableStartNewProperty("Restitution");
			if (ImGui.DragFloat("##Restitution", &restitution, 0.0f, 0.1f, format: "%.3g"))
				polygonCollider.Restitution = restitution;

			float restitutionThreshold = polygonCollider.RestitutionThreshold;
			ImGui.PropertyTableStartNewProperty("Restitution Threshold");
			if (ImGui.DragFloat("##RestitutionThreshold", &restitutionThreshold, 0.0f, 0.1f, format: "%.3g"))
				polygonCollider.RestitutionThreshold = restitutionThreshold;
		}

		private static void ShowScriptComponentEditor(Entity entity, ScriptComponent* scriptComponent)
		{
			static char8[64] buffer = .();

			StringView search = StringView();

			char8* scriptLabel = scriptComponent.ScriptClassName.ToScopeCStr!() ?? "Select Script...";
			
			ImGui.PropertyTableStartNewProperty("Script");
			if (ImGui.Button(scriptLabel))
				ImGui.OpenPopup("SelectScript");

			if (ImGui.BeginPopup("SelectScript"))
			{
				ImGui.InputText("##ScriptSearch", &buffer, buffer.Count);

				search = StringView(&buffer);

				for (let (className, scriptClass) in ScriptEngine.EntityClasses)
				{
					if (!search.IsWhiteSpace && !className.Contains(search, true))
						continue;

					if (ImGui.Selectable(className.ToScopeCStr!(),
						className == scriptComponent.ScriptClassName))
					{
						scriptComponent.ScriptClassName = scriptClass.FullName;
					}
				}
				ImGui.EndPopup();
			}

			ScriptEngine.ShowScriptEditor(entity, scriptComponent);
		}

		private static void ShowLightComponentEditor(Entity entity, LightComponent* lightComponent)
		{
			const String[?] strings = String[]("Directional", "Point", "Spot");

			var light = ref lightComponent.SceneLight;

			String typeName = strings[light.LightType.Underlying];
			
			ImGui.PropertyTableStartNewProperty("Type");
			if (ImGui.BeginCombo("##Type", typeName.CStr()))
			{
				for (int i = 0; i < 3; i++)
				{
					bool isSelected = (typeName == strings[i]);

					if (ImGui.Selectable(strings[i], isSelected))
					{
						light.LightType = (.)i;
					}

					if (isSelected)
						ImGui.SetItemDefaultFocus();
				}

				ImGui.EndCombo();
			}
			
			ColorRGB color = ColorRGB.LinearToSRGB(light.Color);
			ImGui.PropertyTableStartNewProperty("Color");
			if (ImGui.ColorEdit3("##Color", ref color))
				light.Color = ColorRGB.SRgbToLinear(color);

			float illuminance = light.Illuminance;
			ImGui.PropertyTableStartNewProperty("Illuminance");
			if (ImGui.DragFloat("##Illuminance", &illuminance, 0.1f, 0.0f, float.MaxValue, format: "%.3g"))
				light.Illuminance = illuminance;
		}

		private static void ShowMeshComponentEditor(Entity entity, MeshComponent* meshComponent)
		{
			ImGui.PropertyTableStartNewProperty("Mesh");

			GeometryBinding mesh = meshComponent.Mesh;

			StringView identifier = mesh?.Identifier ?? (meshComponent.Mesh.IsValid ? "<Missing Asset>" : "None");
			ImGui.Button(identifier.ToScopeCStr!());

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload(.ContentBrowserItem);

				if (payload != null)
				{
					StringView fullpath = .((char8*)payload.Data, (int)payload.DataSize);

					/*int idx = fullpath.IndexOf('#');

					if (idx == -1)
					{
						// Doesn't make sense here, we NEED a sub asset
						Runtime.NotImplemented();
					}

					StringView filePath = fullpath.Substring(0, idx);
					StringView meshName = fullpath.Substring(idx + 1);*/

					meshComponent.Mesh = Content.LoadAsset(fullpath);

					// TODO: support multiple primitives (treat every primitive as a single mesh? or: mesh can have multiple primitives)
					/*using (GeometryBinding binding = ModelLoader.LoadMesh(filePath, meshName, 0))
					{
						meshComponent.Mesh = binding;
					}*/

					//ModelLoader.LoadModel(scope .(path), )

					/*using (Texture2D newTexture = new Texture2D(path, true))
					{
						newTexture.SamplerState = SamplerStateManager.AnisotropicWrap;
						material.SetTexture(texture.key, newTexture);
					}*/
				}

				ImGui.EndDragDropTarget();
			}
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
						entity.AddComponent<TComponent>();
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
				ShowComponentButton<CircleCollider2DComponent>("Circle collider 2D");
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

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

	class ComponentEditWindow : EditorWindow
	{
		public const String s_WindowTitle = "Components";

		private EntityHierarchyWindow _entityHierarchyWindow;

		private List<(Type, ComponentAttribute attribute)> _componentTypes = new .() ~ delete _;

		public this(EntityHierarchyWindow entityHierarchyWindow)
		{
			_entityHierarchyWindow = entityHierarchyWindow;

			for (let type in Type.Types)
			{
				if (let componentAttribute = type.GetCustomAttribute<ComponentAttribute>())
				{
					_componentTypes.Add((type, componentAttribute));
				}
			}
		}

		protected override void InternalShow()
		{
			ImGui.SetNextWindowSizeConstraints(.(200, 200), .(-1, -1));

			if(!ImGui.Begin(s_WindowTitle, &_open, .None))
			{
				ImGui.PopStyleVar();
				ImGui.End();
				return;
			}

			if (_entityHierarchyWindow.SelectionSize == 1)
			{
				Result<Entity> entityResult = _entityHierarchyWindow.GetSelectedEntity(0);

				if (entityResult case .Ok(let selectedEntity))
					ShowComponents(selectedEntity);
			}
			else
			{
				_editVerticesPolygonCollider2D = false;
			}

			ImGui.End();
		}

		private static uint32 TableId;

		private void ShowComponents(Entity entity)
		{
			float cellPaddingY = ImGui.GetTextLineHeight() / 3.0f;

			ImGui.PushStyleVar(.CellPadding, ImGui.Vec2(ImGui.GetStyle().CellPadding.x, cellPaddingY));

			TableId = ImGui.GetID("properties");

			if (ImGui.BeginTableEx("properties", TableId, 2, .SizingStretchSame | .BordersInner | .Resizable))
			{
				ShowNameComponentEditor(entity);

				ImGui.EndTable();
			}

			ShowComponentEditor<TransformComponent>("Transform", entity, => ShowTransformComponentEditor);
			ShowComponentEditor<CameraComponent>("Camera", entity, => ShowCameraComponentEditor, => ShowComponentContextMenu<CameraComponent>);
			
			ShowComponentEditor<SpriteRendererComponent>("Sprite Renderer", entity, => ShowSpriteRendererComponentEditor, => ShowComponentContextMenu<SpriteRendererComponent>);
			ShowComponentEditor<CircleRendererComponent>("Circle Renderer", entity, => ShowCircleRendererComponentEditor, => ShowComponentContextMenu<CircleRendererComponent>);
			ShowComponentEditor<TextRendererComponent>("Text Renderer", entity, => ShowTextRendererComponentEditor, => ShowComponentContextMenu<TextRendererComponent>);

			ShowComponentEditor<MeshRendererComponent>("Mesh Renderer", entity, => ShowMeshRendererComponentEditor, => ShowComponentContextMenu<MeshRendererComponent>);
			ShowComponentEditor<LightComponent>("Light", entity, => ShowLightComponentEditor, => ShowComponentContextMenu<LightComponent>);
			ShowComponentEditor<MeshComponent>("Mesh", entity, => ShowMeshComponentEditor, => ShowComponentContextMenu<MeshComponent>);

			ShowComponentEditor<Rigidbody2DComponent>("Rigidbody 2D", entity, => ShowRigidBody2DComponentEditor, => ShowComponentContextMenu<Rigidbody2DComponent>);
			ShowComponentEditor<BoxCollider2DComponent>("Box collider 2D", entity, => ShowBoxCollider2DComponentEditor, => ShowComponentContextMenu<BoxCollider2DComponent>);
			ShowComponentEditor<CircleCollider2DComponent>("Circle collider 2D", entity, => ShowCircleCollider2DComponentEditor, => ShowComponentContextMenu<CircleCollider2DComponent>);
			ShowComponentEditor<PolygonCollider2DComponent>("Polygon collider 2D", entity, => ShowPolygonCollider2DComponentEditor, => ShowComponentContextMenu<PolygonCollider2DComponent>);

			ScriptComponent:
			{
				String scriptComponentName = "Script";

				if (entity.TryGetComponent<ScriptComponent>(let scriptComponent) && scriptComponent.Instance != null)
				{
					scriptComponentName = scope:ScriptComponent $"Script ({scriptComponent.ScriptClassName})";
				}

				ShowComponentEditor<ScriptComponent>(scriptComponentName, entity, => ShowScriptComponentEditor, => ShowComponentContextMenu<ScriptComponent>);
			}

			ImGui.PopStyleVar();

			ShowAddComponentButton(entity);
		}

		public void DrawSceneGUI(Entity entity)
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

		private static void ShowComponentEditor<TComponent>(String header, Entity entity, function void(Entity, TComponent*) showComponentEditor, function void(Entity, TComponent*) showComponentContextMenu = null) where TComponent: struct, new
		{
			if (!entity.HasComponent<TComponent>())
				return;

			TComponent* component = entity.GetComponent<TComponent>();

			bool nodeOpen = ImGui.CollapsingHeader(header.CStr(), .DefaultOpen | .AllowOverlap | .Framed | .SpanFullWidth);

			if (showComponentContextMenu != null)
			{
				ImGui.SameLine(ImGui.GetWindowContentRegionMax().x - ImGui.CalcTextSize("...").x - 2 * ImGui.GetStyle().FramePadding.x);

				if (ImGui.SmallButton("..."))
				{
					ImGui.OpenPopup("component_popup");
				}

				if (ImGui.BeginPopup("component_popup"))
				{
					showComponentContextMenu(entity, component);
					
					ImGui.EndPopup();
				}
			}

			if (nodeOpen && ImGui.BeginTableEx("properties", TableId, 2, .SizingStretchSame | .BordersInner | .Resizable))
			{
				if (entity.TryGetComponent<TComponent>(let actualComponent))
					showComponentEditor(entity, actualComponent);

				ImGui.EndTable();
			}
		}

		/// Starts a new row in the table and enters the first column.
		private static void StartNewRow()
		{
			ImGui.TableNextRow();
			ImGui.TableSetColumnIndex(0);
		}

		/// Starts a new property by creating a new table row, writing the name in the first column and entering the second column.
		private static void StartNewProperty(StringView propertyName)
		{
			StartNewRow();

			bool isFirstTableRow = ImGui.TableGetRowIndex() == 0;

			if (isFirstTableRow)
				ImGui.PushItemWidth(-1);

			ImGui.TextUnformatted(propertyName);

			ImGui.AttachTooltip(propertyName);

			ImGui.TableSetColumnIndex(1);
			
			if (isFirstTableRow)
				ImGui.PushItemWidth(-1);
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

			StartNewProperty("Name");

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

			StartNewProperty("Position");
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
			
			StartNewProperty("Rotation");
			if (ImGui.Float3Editor("##Rotation", ref rotationEuler, resetValues: .Zero, dragSpeed: 0.1f, componentEnabled: componentEditable, format: .("%.3f°",)))
			{
				transform.EditorRotationEuler = MathHelper.ToRadians(rotationEuler);
				
				// if necessary reposition Rigidbody2D
				if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
				{
					rigidbody2D.SetAngle(rotationEuler.Z);
				}
			}
			
			float3 scale = transform.Scale;

			StartNewProperty("Scale");
			if (ImGui.Float3Editor("##Scale", ref scale, resetValues: .One, dragSpeed: 0.1f))
				transform.Scale = scale;
		}
		
		static String[] strings = new String[]("Orthographic", "Perspective", "Perspective (Infinite)") ~ delete _;

		private static void ShowCameraComponentEditor(Entity entity, CameraComponent* cameraComponent)
		{
			StartNewProperty("Is Primary");
			ImGui.Checkbox("##Is_Primary", &cameraComponent.Primary);

			var camera = ref cameraComponent.Camera;

			String typeName = strings[camera.ProjectionType.Underlying];
			
			StartNewProperty("Projection");
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
				StartNewProperty("Fov Y");
				float fovY = MathHelper.ToDegrees(camera.PerspectiveFovY);
				if (ImGui.DragFloat("##Fov Y", &fovY, 0.1f, format: "%.3f°"))
					camera.PerspectiveFovY = MathHelper.ToRadians(fovY);
				
				StartNewProperty("Near");
				float near = camera.PerspectiveNearPlane;
				if (ImGui.DragFloat("##Near", &near, 0.1f))
					camera.PerspectiveNearPlane = near;
				
				StartNewProperty("Far");
				float far = camera.PerspectiveFarPlane;
				if (ImGui.DragFloat("##Far", &far, 0.1f))
					camera.PerspectiveFarPlane = far;
			}
			else if (camera.ProjectionType == .InfinitePerspective)
			{
				StartNewProperty("Vertical FOV");
				float fovY = MathHelper.ToDegrees(camera.PerspectiveFovY);
				if (ImGui.DragFloat("##Vertical FOV", &fovY, 0.1f, format: "%.3f°"))
					camera.PerspectiveFovY = MathHelper.ToRadians(fovY);
				
				StartNewProperty("Near");
				float near = camera.PerspectiveNearPlane;
				if (ImGui.DragFloat("##Near", &near, 0.1f))
					camera.PerspectiveNearPlane = near;
			}
			else if (camera.ProjectionType == .Orthographic)
			{
				StartNewProperty("Size");
				float size = camera.OrthographicHeight;
				if (ImGui.DragFloat("##Size", &size, 0.1f))
					camera.OrthographicHeight = size;
				
				StartNewProperty("Near");
				float near = camera.OrthographicNearPlane;
				if (ImGui.DragFloat("##Near", &near, 0.1f))
					camera.OrthographicNearPlane = near;
				
				StartNewProperty("Far");
				float far = camera.OrthographicFarPlane;
				if (ImGui.DragFloat("##Far", &far, 0.1f))
					camera.OrthographicFarPlane = far;
			}
			
			StartNewProperty("Fixed Aspect Ratio");
			bool fixedAspectRatio = camera.FixedAspectRatio;
			if (ImGui.Checkbox("##Fixed Aspect Ratio", &fixedAspectRatio))
				camera.FixedAspectRatio = fixedAspectRatio;

			if (fixedAspectRatio)
			{
				StartNewProperty("Aspect Ratio");
				float aspect = camera.AspectRatio;
				if (ImGui.DragFloat("##Aspect Ratio", &aspect, 0.1f))
					camera.AspectRatio = aspect;
			}
		}

		private static void ShowSpriteRendererComponentEditor(Entity entity, SpriteRendererComponent* spriteRendererComponent)
		{
			ColorRGBA spriteColor = ColorRGBA.LinearToSRGB(spriteRendererComponent.Color);
			StartNewProperty("Color");
			if (ImGui.ColorEdit4("##Color", ref spriteColor))
				spriteRendererComponent.Color = ColorRGBA.SRgbToLinear(spriteColor);
			
			StartNewProperty("Texture");
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

			StartNewProperty("UV Transform");
			ImGui.Float4Editor("##UV Transform", ref spriteRendererComponent.UvTransform, resetValues: float4(0, 0, 1, 1));
		}

		private static void ShowCircleRendererComponentEditor(Entity entity, CircleRendererComponent* circleRendererComponent)
		{
			ColorRGBA spriteColor = ColorRGBA.LinearToSRGB(circleRendererComponent.Color);
			StartNewProperty("Color");
			if (ImGui.ColorEdit4("##Color", ref spriteColor))
				circleRendererComponent.Color = ColorRGBA.SRgbToLinear(spriteColor);
			
			StartNewProperty("Texture");
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

			StartNewProperty("UV Transform");
			ImGui.Float4Editor("##UV Transform", ref circleRendererComponent.UvTransform, resetValues: float4(0, 0, 1, 1));
			
			StartNewProperty("Inner Radius");
			ImGui.DragFloat("##Inner Radius", &circleRendererComponent.InnerRadius, 0.1f, 0.0f, 1.0f);
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
			StartNewProperty("Rich text");

			ImGui.AttachTooltip("If checked, the text will be interpreted as rich text.");

			bool isRichText = textRendererComponent.IsRichText;

			if (ImGui.Checkbox("##rich_text", &isRichText))
			{
				textRendererComponent.IsRichText = isRichText;
				textRendererComponent.NeedsRebuild = true;
			}

			StartNewProperty("Text");

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

			StartNewProperty("Font Size");

			if (ImGui.DragFloat("##fontSize", &textRendererComponent.FontSize))
			{
				textRendererComponent.NeedsRebuild = true;
			}

			StartNewProperty("Color");

			if (ImGui.ColorEdit4("##color", ref textRendererComponent.Color))
			{
				textRendererComponent.NeedsRebuild = true;
			}

			StartNewProperty("Horizontal Alignment");

			if (ImGui.EnumCombo("##horAlign", ref textRendererComponent.HorizontalAlignment))
			{
				textRendererComponent.NeedsRebuild = true;
			}
		}

		private static void ShowMeshRendererComponentEditor(Entity entity, MeshRendererComponent* meshRendererComponent)
		{
			StartNewProperty("Material");
			
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
			
			StartNewProperty("Type");
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
			StartNewProperty("Fixed Rotation");
			if (ImGui.Checkbox("##Fixed Rotation", &isFixedRotation))
			{
				rigidBodyComponent.FixedRotation = isFixedRotation;
			}

			float gravityScale = rigidBodyComponent.GravityScale;
			StartNewProperty("Gravity Scale");
			if (ImGui.DragFloat("##Gravity Scale", &gravityScale))
			{
				rigidBodyComponent.GravityScale = gravityScale;
			}
		}

		private static void ShowBoxCollider2DComponentEditor(Entity entity, BoxCollider2DComponent* boxCollider)
		{
			float2 offset = boxCollider.Offset;
			StartNewProperty("Offset");
			if (ImGui.Float2Editor("##Offset", ref offset, .Zero, 0.1f))
				boxCollider.Offset = offset;

			float2 size = boxCollider.Size;
			StartNewProperty("Size");
			if (ImGui.Float2Editor("##Size", ref size, .Zero, 0.1f, float2(0.01f, 0.01f), float.PositiveInfinity.XX))
				boxCollider.Size = size;
			
			float density = boxCollider.Density;
			StartNewProperty("Density");
			if (ImGui.DragFloat("##Density", &density, 0.0f, 0.1f))
				boxCollider.Density = density;
			
			float friction = boxCollider.Friction;
			StartNewProperty("Friction");
			if (ImGui.DragFloat("##Friction", &friction, 0.0f, 0.1f))
				boxCollider.Friction = friction;

			float restitution = boxCollider.Restitution;
			StartNewProperty("Restitution");
			if (ImGui.DragFloat("##Restitution", &restitution, 0.0f, 0.1f))
				boxCollider.Restitution = restitution;

			float restitutionThreshold = boxCollider.RestitutionThreshold;
			StartNewProperty("Restitution Threshold");
			if (ImGui.DragFloat("##RestitutionThreshold", &restitutionThreshold, 0.0f, 0.1f))
				boxCollider.RestitutionThreshold = restitutionThreshold;
		}

		private static void ShowCircleCollider2DComponentEditor(Entity entity, CircleCollider2DComponent* circleCollider)
		{
			float2 offset = circleCollider.Offset;
			StartNewProperty("Offset");
			if (ImGui.Float2Editor("##Offset", ref offset, .Zero, 0.1f))
				circleCollider.Offset = offset;

			float radius = circleCollider.Radius;
			StartNewProperty("Radius");
			if (ImGui.DragFloat("##Radius", &radius, 0.0f, 0.1f))
				circleCollider.Radius = radius;
			
			float density = circleCollider.Density;
			StartNewProperty("Density");
			if (ImGui.DragFloat("##Density", &density, 0.0f, 0.1f))
				circleCollider.Density = density;
			
			float friction = circleCollider.Friction;
			StartNewProperty("Friction");
			if (ImGui.DragFloat("##Friction", &friction, 0.0f, 0.1f))
				circleCollider.Friction = friction;

			float restitution = circleCollider.Restitution;
			StartNewProperty("Restitution");
			if (ImGui.DragFloat("##Restitution", &restitution, 0.0f, 0.1f))
				circleCollider.Restitution = restitution;

			float restitutionThreshold = circleCollider.RestitutionThreshold;
			StartNewProperty("Restitution Threshold");
			if (ImGui.DragFloat("##RestitutionThreshold", &restitutionThreshold, 0.0f, 0.1f))
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
			StartNewProperty("Offset");
			if (ImGui.Float2Editor("Offset", ref offset, .Zero, 0.1f))
				polygonCollider.Offset = offset;

			StartNewRow();

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
				StartNewProperty("Show Vertex gizmos");
				ImGui.Checkbox("##Show Vertex gizmos", &_editVerticesPolygonCollider2D);

				for (int i < polygonCollider.VertexCount)
				{
					StartNewProperty(scope $"{i}");
					ImGui.Float2Editor(scope $"##{i}", ref polygonCollider.Vertices[i]);
				}

				ImGui.TreePop();
			}

			float density = polygonCollider.Density;
			StartNewProperty("Density");
			if (ImGui.DragFloat("##Density", &density, 0.0f, 0.1f))
				polygonCollider.Density = density;
			
			float friction = polygonCollider.Friction;
			StartNewProperty("Friction");
			if (ImGui.DragFloat("##Friction", &friction, 0.0f, 0.1f))
				polygonCollider.Friction = friction;

			float restitution = polygonCollider.Restitution;
			StartNewProperty("Restitution");
			if (ImGui.DragFloat("##Restitution", &restitution, 0.0f, 0.1f))
				polygonCollider.Restitution = restitution;

			float restitutionThreshold = polygonCollider.RestitutionThreshold;
			StartNewProperty("Restitution Threshold");
			if (ImGui.DragFloat("##RestitutionThreshold", &restitutionThreshold, 0.0f, 0.1f))
				polygonCollider.RestitutionThreshold = restitutionThreshold;
		}

		private static void ShowScriptComponentEditor(Entity entity, ScriptComponent* scriptComponent)
		{
			static char8[64] buffer = .();

			StringView search = StringView();

			char8* scriptLabel = scriptComponent.ScriptClassName.ToScopeCStr!() ?? "Select Script...";
			
			StartNewProperty("Script");
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
			
			StartNewProperty("Type");
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
			StartNewProperty("Color");
			if (ImGui.ColorEdit3("##Color", ref color))
				light.Color = ColorRGB.SRgbToLinear(color);

			float illuminance = light.Illuminance;
			StartNewProperty("Illuminance");
			if (ImGui.DragFloat("##Illuminance", &illuminance, 0.1f, 0.0f, float.MaxValue))
				light.Illuminance = illuminance;
		}

		private static void ShowMeshComponentEditor(Entity entity, MeshComponent* meshComponent)
		{
			StartNewProperty("Mesh");

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

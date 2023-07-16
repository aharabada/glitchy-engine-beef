using ImGui;
using GlitchyEngine.World;
using System;
using GlitchyEngine.Math;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine;
using GlitchyEngine.Content;
using GlitchyEngine.Scripting;

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
			ImGui.PushStyleVar(.WindowMinSize, ImGui.Vec2(1000, 100));

			if(!ImGui.Begin(s_WindowTitle, &_open, .None))
			{
				ImGui.PopStyleVar();
				ImGui.End();
				return;
			}
			
			if(_entityHierarchyWindow.SelectedEntities.Count == 1)
			{
				Entity entity = _entityHierarchyWindow.SelectedEntities.Front;

				ShowComponents(entity);
			}
			
			ImGui.PopStyleVar();
			ImGui.End();
		}

		private void ShowComponents(Entity entity)
		{
			ShowNameComponentEditor(entity);

			ShowComponentEditor<TransformComponent>("Transform", entity, => ShowTransformComponentEditor);
			ShowComponentEditor<CameraComponent>("Camera", entity, => ShowCameraComponentEditor, => ShowComponentContextMenu<CameraComponent>);
			ShowComponentEditor<SpriteRendererComponent>("Sprite Renderer", entity, => ShowSpriteRendererComponentEditor, => ShowComponentContextMenu<SpriteRendererComponent>);
			ShowComponentEditor<CircleRendererComponent>("Circle Renderer", entity, => ShowCircleRendererComponentEditor, => ShowComponentContextMenu<CircleRendererComponent>);
			ShowComponentEditor<MeshRendererComponent>("Mesh Renderer", entity, => ShowMeshRendererComponentEditor, => ShowComponentContextMenu<MeshRendererComponent>);
			ShowComponentEditor<LightComponent>("Light", entity, => ShowLightComponentEditor, => ShowComponentContextMenu<LightComponent>);
			ShowComponentEditor<MeshComponent>("Mesh", entity, => ShowMeshComponentEditor, => ShowComponentContextMenu<MeshComponent>);
			ShowComponentEditor<Rigidbody2DComponent>("Rigidbody 2D", entity, => ShowRigidBody2DComponentEditor, => ShowComponentContextMenu<Rigidbody2DComponent>);
			ShowComponentEditor<BoxCollider2DComponent>("Box collider 2D", entity, => ShowBoxCollider2DComponentEditor, => ShowComponentContextMenu<BoxCollider2DComponent>);
			ShowComponentEditor<CircleCollider2DComponent>("Circle collider 2D", entity, => ShowCircleCollider2DComponentEditor, => ShowComponentContextMenu<CircleCollider2DComponent>);
			ShowComponentEditor<ScriptComponent>("Script Component", entity, => ShowScriptComponentEditor, => ShowComponentContextMenu<ScriptComponent>);

			ShowAddComponentButton(entity);
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

			ImGui.PushID(header);

			bool nodeOpen = ImGui.TreeNodeEx(header.CStr(), .DefaultOpen | .AllowItemOverlap | .Framed | .SpanFullWidth);

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

			if (nodeOpen)
			{
				showComponentEditor(entity, component);

				ImGui.TreePop();
			}

			ImGui.PopID();
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

			if(ImGui.InputText("Name", &nameBuffer, nameBuffer.Count))
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
			if (ImGui.Editfloat3("Position", ref position, .Zero, 0.1f, textWidth))
			{
				transform.Position = position;

				// if necessary reposition Rigidbody2D
				if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
				{
					rigidbody2D.SetPosition(position.XY);
				}
			}

			float3 rotationEuler = MathHelper.ToDegrees(transform.EditorRotationEuler);
			if (ImGui.Editfloat3("Rotation", ref rotationEuler, .Zero, 0.1f, textWidth))
			{
				transform.EditorRotationEuler = MathHelper.ToRadians(rotationEuler);
				
				// if necessary reposition Rigidbody2D
				if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
				{
					rigidbody2D.SetAngle(rotationEuler.Z);
				}
			}
			
			float3 scale = transform.Scale;
			if (ImGui.Editfloat3("Scale", ref scale, .One, 0.1f, textWidth))
				transform.Scale = scale;
		}
		
		static String[] strings = new String[]("Orthographic", "Perspective", "Perspective (Infinite)") ~ delete _;

		private static void ShowCameraComponentEditor(Entity entity, CameraComponent* cameraComponent)
		{
			ImGui.Checkbox("Primary", &cameraComponent.Primary);

			var camera = ref cameraComponent.Camera;

			String typeName = strings[camera.ProjectionType.Underlying];

			if (ImGui.BeginCombo("Projection", typeName.CStr()))
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
				float fovY = MathHelper.ToDegrees(camera.PerspectiveFovY);
				if (ImGui.DragFloat("Fov Y", &fovY, 0.1f))
					camera.PerspectiveFovY = MathHelper.ToRadians(fovY);
				
				float near = camera.PerspectiveNearPlane;
				if (ImGui.DragFloat("Near", &near, 0.1f))
					camera.PerspectiveNearPlane = near;

				float far = camera.PerspectiveFarPlane;
				if (ImGui.DragFloat("Far", &far, 0.1f))
					camera.PerspectiveFarPlane = far;
			}
			else if (camera.ProjectionType == .InfinitePerspective)
			{
				float fovY = MathHelper.ToDegrees(camera.PerspectiveFovY);
				if (ImGui.DragFloat("Vertical FOV", &fovY, 0.1f))
					camera.PerspectiveFovY = MathHelper.ToRadians(fovY);
				
				float near = camera.PerspectiveNearPlane;
				if (ImGui.DragFloat("Near", &near, 0.1f))
					camera.PerspectiveNearPlane = near;
			}
			else if (camera.ProjectionType == .Orthographic)
			{
				float size = camera.OrthographicHeight;
				if (ImGui.DragFloat("Size", &size, 0.1f))
					camera.OrthographicHeight = size;
				
				float near = camera.OrthographicNearPlane;
				if (ImGui.DragFloat("Near", &near, 0.1f))
					camera.OrthographicNearPlane = near;

				float far = camera.OrthographicFarPlane;
				if (ImGui.DragFloat("Far", &far, 0.1f))
					camera.OrthographicFarPlane = far;
			}

			bool fixedAspectRatio = camera.FixedAspectRatio;
			if (ImGui.Checkbox("Fixed Aspect Ratio", &fixedAspectRatio))
				camera.FixedAspectRatio = fixedAspectRatio;

			if (fixedAspectRatio)
			{
				float aspect = camera.AspectRatio;
				if (ImGui.DragFloat("Aspect Ratio", &aspect, 0.1f))
					camera.AspectRatio = aspect;
			}
		}

		private static void ShowSpriteRendererComponentEditor(Entity entity, SpriteRendererComponent* spriteRendererComponent)
		{
			ColorRGBA spriteColor = ColorRGBA.LinearToSRGB(spriteRendererComponent.Color);
			if (ImGui.ColorEdit4("Color", ref spriteColor))
				spriteRendererComponent.Color = ColorRGBA.SRgbToLinear(spriteColor);

			ImGui.Button("Texture");

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");

				if (payload != null)
				{
					Log.EngineLogger.Warning("");

					StringView path = .((char8*)payload.Data, (int)payload.DataSize);

					spriteRendererComponent.Sprite = Content.LoadAsset(path);
				}

				ImGui.EndDragDropTarget();
			}


			ImGui.EditVector<4>("UV Transform", ref *(float[4]*)&spriteRendererComponent.UvTransform);
		}

		private static void ShowCircleRendererComponentEditor(Entity entity, CircleRendererComponent* circleRendererComponent)
		{
			ColorRGBA spriteColor = ColorRGBA.LinearToSRGB(circleRendererComponent.Color);
			if (ImGui.ColorEdit4("Color", ref spriteColor))
				circleRendererComponent.Color = ColorRGBA.SRgbToLinear(spriteColor);

			ImGui.Button("Texture");

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");

				if (payload != null)
				{
					Log.EngineLogger.Warning("");

					StringView path = .((char8*)payload.Data, (int)payload.DataSize);

					circleRendererComponent.Sprite = Content.LoadAsset(path);
				}

				ImGui.EndDragDropTarget();
			}


			ImGui.EditVector<4>("UV Transform", ref *(float[4]*)&circleRendererComponent.UvTransform);

			ImGui.DragFloat("Inner Radius", &circleRendererComponent.InnerRadius, 0.1f, 0.0f, 1.0f);
		}

		private static void ShowMeshRendererComponentEditor(Entity entity, MeshRendererComponent* meshRendererComponent)
		{
			ImGui.TextUnformatted("Material:");
			ImGui.SameLine();
			
			Material material = meshRendererComponent.Material;

			StringView identifier = material?.Identifier ?? "None";
			ImGui.Button(identifier.ToScopeCStr!());

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");

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

			if (ImGui.BeginCombo("Type", bodyTypeName.CStr()))
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


			ImGui.Checkbox("Fixed Rotation", &rigidBodyComponent.FixedRotation);
		}

		private static void ShowBoxCollider2DComponentEditor(Entity entity, BoxCollider2DComponent* boxCollider)
		{
			float textWidth = ImGui.CalcTextSize("Offset".CStr()).x;
			textWidth += ImGui.GetStyle().FramePadding.x * 3.0f;


			float2 offset = boxCollider.Offset;
			if (ImGui.Editfloat2("Offset", ref offset, .Zero, 0.1f, textWidth))
				boxCollider.Offset = offset;

			float2 size = boxCollider.Size;
			if (ImGui.Editfloat2("Size", ref size, .Zero, 0.1f, textWidth))
				boxCollider.Size = size;
			
			float density = boxCollider.Density;
			if (ImGui.DragFloat("Density", &density, 0.0f, 0.1f, textWidth))
				boxCollider.Density = density;
			
			float friction = boxCollider.Friction;
			if (ImGui.DragFloat("Friction", &friction, 0.0f, 0.1f, textWidth))
				boxCollider.Friction = friction;

			float restitution = boxCollider.Restitution;
			if (ImGui.DragFloat("Restitution", &restitution, 0.0f, 0.1f, textWidth))
				boxCollider.Restitution = restitution;

			float restitutionThreshold = boxCollider.RestitutionThreshold;
			if (ImGui.DragFloat("RestitutionThreshold", &restitutionThreshold, 0.0f, 0.1f, textWidth))
				boxCollider.RestitutionThreshold = restitutionThreshold;
		}

		private static void ShowCircleCollider2DComponentEditor(Entity entity, CircleCollider2DComponent* circleCollider)
		{
			float textWidth = ImGui.CalcTextSize("Offset".CStr()).x;
			textWidth += ImGui.GetStyle().FramePadding.x * 3.0f;


			float2 offset = circleCollider.Offset;
			if (ImGui.Editfloat2("Offset", ref offset, .Zero, 0.1f, textWidth))
				circleCollider.Offset = offset;

			float radius = circleCollider.Radius;
			if (ImGui.DragFloat("Radius", &radius, 0.0f, 0.1f, textWidth))
				circleCollider.Radius = radius;
			
			float density = circleCollider.Density;
			if (ImGui.DragFloat("Density", &density, 0.0f, 0.1f, textWidth))
				circleCollider.Density = density;
			
			float friction = circleCollider.Friction;
			if (ImGui.DragFloat("Friction", &friction, 0.0f, 0.1f, textWidth))
				circleCollider.Friction = friction;

			float restitution = circleCollider.Restitution;
			if (ImGui.DragFloat("Restitution", &restitution, 0.0f, 0.1f, textWidth))
				circleCollider.Restitution = restitution;

			float restitutionThreshold = circleCollider.RestitutionThreshold;
			if (ImGui.DragFloat("RestitutionThreshold", &restitutionThreshold, 0.0f, 0.1f, textWidth))
				circleCollider.RestitutionThreshold = restitutionThreshold;
		}

		private static void ShowScriptComponentEditor(Entity entity, ScriptComponent* scriptComponent)
		{
			static char8[64] buffer = .();

			StringView search = StringView();

			char8* scriptLabel = scriptComponent.Instance?.ScriptClass.FullName.ToScopeCStr!() ?? "Select Script...";

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
						className == scriptComponent.Instance?.ScriptClass.FullName))
					{
						//scriptComponent.Instance = new ScriptInstance(scriptClass);
						// decrement refCount to 1 (scriptComponent.Instance increments its)
						//scriptComponent.Instance.ReleaseRef();
						//ScriptEngine.InitializeInstance(entity, scriptComponent);

						scriptComponent.ScriptClass = scriptClass;
						
						ScriptEngine.CreateScriptFieldMap(entity);
					}
				}
				ImGui.EndPopup();
			}

			/*T GetFieldValue<T>()
			{
				return scriptComponent.Instance.GetFieldValue<T>(monoField);
			}

			void SetFieldValue<T>(in T value)
			{
				scriptComponent.Instance.SetFieldValue<T>(monoField, value);
			}*/
			
			T GetFieldValue<T>(ScriptInstance scriptInstance, in ScriptField scriptField)
			{
				return scriptInstance.GetFieldValue<T>(scriptField);
			}
			
			void GetFieldValue<T>(ScriptInstance scriptInstance, in ScriptField scriptField, out T value)
			{
				value = scriptInstance.GetFieldValue<T>(scriptField);
			}

			void SetFieldValue<T>(ScriptInstance scriptInstance, in ScriptField scriptField, in T value)
			{
				scriptInstance.SetFieldValue<T>(scriptField, value);
			}

			if (scriptComponent.Instance?.IsInitialized == true)
			{
				SharpClass sharpClass = scriptComponent.Instance.ScriptClass;
				ScriptInstance scriptInstance = scriptComponent.Instance;

				for (let (fieldName, scriptField) in sharpClass.Fields)
				{
					var monoField = scriptField.[Friend]_monoField;
					
					switch (scriptField.FieldType)
					{
					case .Bool:
						var value = GetFieldValue<bool>(scriptInstance, scriptField);
						if (ImGui.Checkbox(fieldName.ToScopeCStr!(), &value))
							SetFieldValue(scriptInstance, scriptField, value);

					case .SByte:
						var value = GetFieldValue<int8>(scriptInstance, scriptField);
						if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .S8, &value))
							SetFieldValue(scriptInstance, scriptField, value);
					case .Short:
						var value = GetFieldValue<int16>(scriptInstance, scriptField);
						if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .S16, &value))
							SetFieldValue(scriptInstance, scriptField, value);
					case .Int:
						var value = GetFieldValue<int32>(scriptInstance, scriptField);
						if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .S32, &value))
							SetFieldValue(scriptInstance, scriptField, value);
					case .Long:
						var value = GetFieldValue<int64>(scriptInstance, scriptField);
						if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .S64, &value))
							SetFieldValue(scriptInstance, scriptField, value);

					case .Byte:
						var value = GetFieldValue<uint8>(scriptInstance, scriptField);
						if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .U8, &value))
							SetFieldValue(scriptInstance, scriptField, value);
					case .UShort:
						var value = GetFieldValue<uint16>(scriptInstance, scriptField);
						if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .U16, &value))
							SetFieldValue(scriptInstance, scriptField, value);
					case .UInt:
						var value = GetFieldValue<uint32>(scriptInstance, scriptField);
						if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .U32, &value))
							SetFieldValue(scriptInstance, scriptField, value);
					case .ULong:
						var value = GetFieldValue<uint64>(scriptInstance, scriptField);
						if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .U64, &value))
							SetFieldValue(scriptInstance, scriptField, value);

					case .Float:
						var value = GetFieldValue<float>(scriptInstance, scriptField);
						if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .Float, &value))
							SetFieldValue(scriptInstance, scriptField, value);

					case .float2:
						GetFieldValue<float2>(scriptInstance, scriptField, var value);
						if (ImGui.Editfloat2(fieldName, ref value))
							SetFieldValue(scriptInstance, scriptField, value);
					case .float3:
						GetFieldValue<float3>(scriptInstance, scriptField, var value);
						if (ImGui.Editfloat3(fieldName, ref value))
							SetFieldValue(scriptInstance, scriptField, value);
					case .float4:
						GetFieldValue<float4>(scriptInstance, scriptField, var value);
						if (ImGui.Editfloat4(fieldName, ref value))
							SetFieldValue(scriptInstance, scriptField, value);

					case .Double:
						var value = GetFieldValue<double>(scriptInstance, scriptField);
						if (ImGui.DragScalar(fieldName.ToScopeCStr!(), .Double, &value))
							SetFieldValue(scriptInstance, scriptField, value);

					case .Entity:
						// TODO!
						
					case .Enum:
						// TODO!
					case .Struct:
						// TODO!
					default:
						Log.EngineLogger.Error($"Unhandled field type {scriptField.FieldType}");
					}
				}
			}
			else if (scriptComponent.ScriptClass != null)
			{
				let scriptFields = ScriptEngine.GetScriptFieldMap(entity);

				for (var (name, field) in ref scriptFields)
				{
					switch (field.Field.FieldType)
					{
					case .Bool:
						var value = field.GetData<bool>();
						if (ImGui.Checkbox(name.ToScopeCStr!(), &value))
							field.SetData(value);

					case .SByte:
						var value = field.GetData<int8>();
						if (ImGui.DragScalar(name.ToScopeCStr!(), .S8, &value))
							field.SetData(value);
						case .Short:
							var value = field.GetData<int16>();
							if (ImGui.DragScalar(name.ToScopeCStr!(), .S16, &value))
								field.SetData(value);
					case .Int:
							var value = field.GetData<int32>();
							if (ImGui.DragScalar(name.ToScopeCStr!(), .S32, &value))
								field.SetData(value);
					case .Int2:
							var value = field.GetData<int2>();
							if (ImGui.DragScalarN(name.ToScopeCStr!(), .S32, &value, 2))
								field.SetData(value);
					case .Int3:
							var value = field.GetData<int3>();
							if (ImGui.DragScalarN(name.ToScopeCStr!(), .S32, &value, 3))
								field.SetData(value);
					case .Int4:
							var value = field.GetData<int4>();
							if (ImGui.DragScalarN(name.ToScopeCStr!(), .S32, &value, 4))
								field.SetData(value);
					case .Long:
							var value = field.GetData<int64>();
							if (ImGui.DragScalar(name.ToScopeCStr!(), .S64, &value))
								field.SetData(value);

					case .Byte:
							var value = field.GetData<uint8>();
							if (ImGui.DragScalar(name.ToScopeCStr!(), .U8, &value))
								field.SetData(value);
					case .UShort:
							var value = field.GetData<uint16>();
							if (ImGui.DragScalar(name.ToScopeCStr!(), .U16, &value))
								field.SetData(value);
					case .UInt:
							var value = field.GetData<uint32>();
							if (ImGui.DragScalar(name.ToScopeCStr!(), .U32, &value))
								field.SetData(value);
					case .ULong:
							var value = field.GetData<uint64>();
							if (ImGui.DragScalar(name.ToScopeCStr!(), .U64, &value))
								field.SetData(value);

					case .Float:
							var value = field.GetData<float>();
							if (ImGui.DragScalar(name.ToScopeCStr!(), .Float, &value))
								field.SetData(value);
					case .float2:
							var value = field.GetData<float2>();
							if (ImGui.Editfloat2(name, ref value))
								field.SetData(value);
					case .float3:
							var value = field.GetData<float3>();
							if (ImGui.Editfloat3(name, ref value))
								field.SetData(value);
					case .float4:
							var value = field.GetData<float4>();
							if (ImGui.Editfloat4(name, ref value))
								field.SetData(value);

					case .Double:
							var value = field.GetData<double>();
							if (ImGui.DragScalar(name.ToScopeCStr!(), .Double, &value))
								field.SetData(value);
					case .Double2:
							var value = field.GetData<double2>();
							if (ImGui.DragScalarN(name.ToScopeCStr!(), .Double, &value, 2))
								field.SetData(value);
					case .Double3:
							var value = field.GetData<double3>();
							if (ImGui.DragScalarN(name.ToScopeCStr!(), .Double, &value, 3))
								field.SetData(value);
					case .Double4:
							var value = field.GetData<double4>();
							if (ImGui.DragScalarN(name.ToScopeCStr!(), .Double, &value, 4))
								field.SetData(value);

					case .Enum:
						// TODO!
						
					//case .String:
						// TODO!

					case .Entity:
						// TODO!

					case .Struct:
						// TODO!

					default:
						Log.EngineLogger.Error($"Unhandled field type {field.Field.FieldType}");
					}
				}
			}
		}

		private static void LabelColumn(StringView label)
		{
			ImGui.TextUnformatted(label);
			ImGui.NextColumn();
		}

		private static void ShowLightComponentEditor(Entity entity, LightComponent* lightComponent)
		{
			ImGui.Columns(2);
			defer ImGui.Columns(1);

			const String[?] strings = String[]("Directional", "Point", "Spot");

			var light = ref lightComponent.SceneLight;

			String typeName = strings[light.LightType.Underlying];
			
			LabelColumn("Type");

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
			
			ImGui.NextColumn();
			LabelColumn("Color");

			ColorRGB color = ColorRGB.LinearToSRGB(light.Color);
			if (ImGui.ColorEdit3("##Color", ref color))
				light.Color = ColorRGB.SRgbToLinear(color);

			ImGui.NextColumn();
			LabelColumn("Illuminance");

			float illuminance = light.Illuminance;
			if (ImGui.DragFloat("##Illuminance", &illuminance, 0.1f, 0.0f, float.MaxValue))
				light.Illuminance = illuminance;
		}

		private static void ShowMeshComponentEditor(Entity entity, MeshComponent* meshComponent)
		{
			ImGui.TextUnformatted("Mesh:");
			ImGui.SameLine();

			GeometryBinding mesh = meshComponent.Mesh;

			StringView identifier = mesh?.Identifier ?? "None";
			ImGui.Button(identifier.ToScopeCStr!());

			if (ImGui.BeginDragDropTarget())
			{
				ImGui.Payload* payload = ImGui.AcceptDragDropPayload("CONTENT_BROWSER_ITEM");

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

			ImGui.NewLine();
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
				ShowComponentButton<LightComponent>("Light");
				ShowComponentButton<Rigidbody2DComponent>("Rigidbody 2D");
				ShowComponentButton<BoxCollider2DComponent>("Box collider 2D");
				ShowComponentButton<CircleCollider2DComponent>("Circle collider 2D");
				ShowComponentButton<MeshComponent>("Mesh");
				ShowComponentButton<MeshRendererComponent>("Mesh Renderer");
				ShowComponentButton<ScriptComponent>("C# Script");

				ImGui.EndCombo();
			}

			ImGui.PopItemWidth();
		}
	}
}

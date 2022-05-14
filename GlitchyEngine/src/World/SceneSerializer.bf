using Bon;
using Bon.Integrated;
using System;
using System.Reflection;
using System.IO;
using GlitchyEngine.Math;

namespace GlitchyEngine.World
{
	using internal GlitchyEngine.World;

	class SceneSerializer
	{
		private Scene _scene;

		public this(Scene scene)
		{
			_scene = scene;
		}

		public void Serialize(StringView filePath)
		{
			Debug.Profiler.ProfileResourceFunction!();

			String buffer = scope String();
			let writer = scope BonWriter(buffer, true);
			Serialize.Start(writer);

			gBonEnv.serializeFlags |= .IncludeDefault | .Verbose;

			using (writer.ObjectBlock())
			{
				// TODO: Scene name goes here!
				Serialize.Value(writer, "Name", "Scene name here pls!!!");
				
				writer.Identifier("Entities");

				using (writer.ArrayBlock())
				{
					for (EcsEntity e in _scene._ecsWorld.Enumerate())
					{
						Entity entity = .(e, _scene);

						// TODO: also serialize object with EditorComponent (e.g. to save the location of the editor camera)
						if (entity.HasComponent<EditorComponent>())
							continue;

						SerializeEntity(writer, entity);
					}
				}

				writer.EntryEnd();
			}
			
			Serialize.End(writer);

			String targetDirectory = Path.GetDirectoryPath(filePath, .. scope String());
			Directory.CreateDirectory(targetDirectory);

			File.WriteAllText(filePath, buffer);
		}

		static void SerializeEntity(BonWriter writer, Entity entity)
		{
			writer.EntryStart();

			using (writer.ObjectBlock())
			{
				// TODO: Entity GUID goes here!
				Serialize.Value(writer, "Id", entity.Handle.Index);
				
				SerializeComponent<EditorComponent>(writer, entity, "EditorComponent", scope (component) => {});

				SerializeComponent<DebugNameComponent>(writer, entity, "NameComponent", scope (component) =>
				{
					Serialize.Value(writer, "Name", component.DebugName);
				});

				SerializeComponent<SpriterRendererComponent>(writer, entity, "SpriterRendererComponent", scope (component) =>
				{
					// TODO: Texture

					Serialize.Value(writer, "Color", component.Color);
				});

				SerializeComponent<TransformComponent>(writer, entity, "TransformComponent", scope (component) =>
				{
					// TODO: Use GUIDs
					if (component.Parent != .InvalidEntity)
						Serialize.Value(writer, "ParentId", component.Parent.Index);

					Serialize.Value(writer, "Position", component.Position);
					Serialize.Value(writer, "Rotation", component.Rotation);
					Serialize.Value(writer, "Scale", component.Scale);

					Serialize.Value(writer, "EditorEulerRotation", component.EditorRotationEuler);
				});

				SerializeComponent<CameraComponent>(writer, entity, "CameraComponent", scope (component) =>
				{
					SceneCamera camera = component.Camera;

					Serialize.Value(writer, "Primary", component.Primary);

					// TODO: Render target
					
					Serialize.Value(writer, "ProjectionType", camera.ProjectionType);
					
					Serialize.Value(writer, "PerspectiveFovY", camera.PerspectiveFovY);
					Serialize.Value(writer, "PerspectiveNearPlane", camera.PerspectiveNearPlane);
					Serialize.Value(writer, "PerspectiveFarPlane", camera.PerspectiveFarPlane);
					Serialize.Value(writer, "OrthographicHeight", camera.OrthographicHeight);
					Serialize.Value(writer, "OrthographicNearPlane", camera.OrthographicNearPlane);
					Serialize.Value(writer, "OrthographicFarPlane", camera.OrthographicFarPlane);
					Serialize.Value(writer, "AspectRatio", camera.AspectRatio);
					Serialize.Value(writer, "FixedAspectRatio", camera.FixedAspectRatio);
				});

				// TODO: native script component
				
				SerializeComponent<LightComponent>(writer, entity, "LightComponent", scope (component) =>
				{
					SceneLight light = component.SceneLight;

					Serialize.Value(writer, "LightType", light.LightType);

					Serialize.Value(writer, "Illuminance", light.Illuminance);

					Serialize.Value(writer, "Color", light.Color);
				});
			}

			writer.EntryEnd();
		}

		static void SerializeComponent<T>(BonWriter writer, Entity entity, String identifier, delegate void(T* component) serialize) where T : struct, new
		{
			if (!entity.HasComponent<T>())
				return;

			var component = entity.GetComponent<T>();

			writer.Identifier(identifier);

			using (writer.ObjectBlock())
			{
				serialize(component);
			}
			writer.EntryEnd();
		}
		
		public void SerializeRuntime(StringView filePath)
		{
			Runtime.NotImplemented();
		}
		
		public Result<void> Deserialize(StringView filePath)
		{
			Debug.Profiler.ProfileResourceFunction!();

			String buffer = scope String();
			File.ReadAllText(filePath, buffer);

			let reader = scope BonReader();
			Try!(reader.Setup(buffer));
			Try!(Deserialize.Start(reader));

			Try!(reader.ObjectBlock());
			
			// TODO: Scene name goes here!
			String testName;
			Deserialize.Value(reader, "Name", out testName);
			delete testName;

			Try!(reader.EntryEnd());

			if (Try!(reader.Identifier()) != "Entities")
				return .Err;

			Try!(reader.ArrayBlock());

			bool first = true;
			while (reader.ArrayHasMore())
			{
				if (!first)
				{
					Try!(reader.EntryEnd());
				}
				
				Try!(DeserializeEntity(reader));

				first = false;
			}

			Try!(reader.ArrayBlockEnd());

			Try!(reader.ObjectBlockEnd());

			Try!(Deserialize.End(reader));

			return .Ok;
		}

		private Result<void> DeserializeEntity(BonReader reader)
		{
			Try!(reader.ObjectBlock());
			
			Entity entity = _scene.CreateEntity();

			// TODO: GUID?
			Deserialize.Value<uint32>(reader, "Id", let id);

			while(reader.ObjectHasMore())
			{
				Try!(reader.EntryEnd());

				StringView identifier = Try!(reader.Identifier());

				switch(identifier)
				{
				case "EditorComponent":
					Try!(DeserializeComponent<EditorComponent>(reader, entity, scope (component) => { return .Ok; }));
				case "NameComponent":
					Try!(DeserializeComponent<DebugNameComponent>(reader, entity, scope (component) =>
					{
						String name;

						Deserialize.Value(reader, "Name", out name);

						component.SetName(name);

						delete name;

						return .Ok;
					}));
				case "NameComponent":
					Try!(DeserializeComponent<DebugNameComponent>(reader, entity, scope (component) =>
					{
						String name;

						Deserialize.Value(reader, "Name", out name);

						component.SetName(name);

						delete name;

						return .Ok;
					}));
				case "SpriterRendererComponent":
					Try!(DeserializeComponent<SpriterRendererComponent>(reader, entity, scope (component) =>
					{
						// TODO: Texture

						Try!(Deserialize.Value(reader, "Color", out component.Color));

						return .Ok;
					}));
				case "TransformComponent":
					Try!(DeserializeComponent<TransformComponent>(reader, entity, scope (component) =>
					{
						let nextId = Try!(reader.Identifier());
						if (nextId == "ParentId")
						{
							// TODO: Use GUIDs
							uint32 pId;
							Deserialize.Value(reader, out pId);
							reader.EntryEnd();
							Deserialize.Value(reader, "Position", out component.[Friend]_position);
							reader.EntryEnd();
						}
						else if (nextId == "Position")
						{
							Deserialize.Value(reader, out component.[Friend]_position);
							reader.EntryEnd();
						}
	 					else
						{
							return .Err;
						}

						Deserialize.Value(reader, "Rotation", out component.[Friend]_rotation);
						reader.EntryEnd();
						Deserialize.Value(reader, "Scale", out component.[Friend]_scale);
						reader.EntryEnd();
						
						Deserialize.Value(reader, "EditorEulerRotation", out component.[Friend]_editorRotationEuler);

						component.IsDirty = true;

						return .Ok;
					}));
				case "CameraComponent":
					Try!(DeserializeComponent<CameraComponent>(reader, entity, scope (component) =>
					{
						SceneCamera camera = component.Camera;

						Deserialize.Value(reader, "Primary", out component.Primary);
						reader.EntryEnd();

						// TODO: Render target

						Deserialize.Value(reader, "ProjectionType", out camera.[Friend]_projectionType);
						reader.EntryEnd();

						Deserialize.Value(reader, "PerspectiveFovY", out camera.[Friend]_perspectiveFovY);
						reader.EntryEnd();
						Deserialize.Value(reader, "PerspectiveNearPlane", out camera.[Friend]_perspectiveNearPlane);
						reader.EntryEnd();
						Deserialize.Value(reader, "PerspectiveFarPlane", out camera.[Friend]_perspectiveFarPlane);
						reader.EntryEnd();
						Deserialize.Value(reader, "OrthographicHeight", out camera.[Friend]_orthographicHeight);
						reader.EntryEnd();
						Deserialize.Value(reader, "OrthographicNearPlane", out camera.[Friend]_orthographicNearPlane);
						reader.EntryEnd();
						Deserialize.Value(reader, "OrthographicFarPlane", out camera.[Friend]_orthographicFarPlane);
						reader.EntryEnd();
						Deserialize.Value(reader, "AspectRatio", out camera.[Friend]_aspectRatio);
						reader.EntryEnd();
						Deserialize.Value(reader, "FixedAspectRatio", out camera.[Friend]_fixedAspectRatio);

						camera.[Friend]CalculateProjection();

						return .Ok;
					}));
				// TODO: native script component
				case "LightComponent":
					Try!(DeserializeComponent<LightComponent>(reader, entity, scope (component) =>
					{
						SceneLight light = component.SceneLight;

						Deserialize.Value(reader, "LightType", out light.[Friend]_type);
						reader.EntryEnd();

						Deserialize.Value(reader, "Illuminance", out light.[Friend]_illuminance);
						reader.EntryEnd();

						Deserialize.Value(reader, "Color", out light.[Friend]_color);
						return .Ok;
					}));

				default:
					return .Err;
				}
			}

			Try!(reader.ObjectBlockEnd());

			return .Ok;

			/*writer.EntryStart();

			using (writer.ObjectBlock())
			{
				// TODO: Entity GUID goes here!
				Serialize.Value(writer, "Id", entity.Handle.Index);
				
				SerializeComponent<EditorComponent>(writer, entity, "EditorComponent", scope (component) => {});

				SerializeComponent<DebugNameComponent>(writer, entity, "NameComponent", scope (component) =>
				{
					Serialize.Value(writer, "Name", component.DebugName);
				});

				SerializeComponent<SpriterRendererComponent>(writer, entity, "SpriterRendererComponent", scope (component) =>
				{
					// TODO: Texture

					Serialize.Value(writer, "Color", component.Color);
				});

				SerializeComponent<TransformComponent>(writer, entity, "TransformComponent", scope (component) =>
				{
					// TODO: Use GUIDs
					if (component.Parent != .InvalidEntity)
						Serialize.Value(writer, "ParentId", component.Parent.Index);

					Serialize.Value(writer, "Position", component.Position);
					Serialize.Value(writer, "Rotation", component.Rotation);
					Serialize.Value(writer, "Scale", component.Scale);

					Serialize.Value(writer, "EditorEulerRotation", component.EditorRotationEuler);
				});

				SerializeComponent<CameraComponent>(writer, entity, "CameraComponent", scope (component) =>
				{
					SceneCamera camera = component.Camera;

					Serialize.Value(writer, "Primary", component.Primary);

					// TODO: Render target
					
					Serialize.Value(writer, "ProjectionType", camera.ProjectionType);
					
					Serialize.Value(writer, "PerspectiveFovY", camera.PerspectiveFovY);
					Serialize.Value(writer, "PerspectiveNearPlane", camera.PerspectiveNearPlane);
					Serialize.Value(writer, "PerspectiveFarPlane", camera.PerspectiveFarPlane);
					Serialize.Value(writer, "OrthographicHeight", camera.OrthographicHeight);
					Serialize.Value(writer, "OrthographicNearPlane", camera.OrthographicNearPlane);
					Serialize.Value(writer, "OrthographicFarPlane", camera.OrthographicFarPlane);
					Serialize.Value(writer, "AspectRatio", camera.AspectRatio);
					Serialize.Value(writer, "FixedAspectRatio", camera.FixedAspectRatio);
				});

				// TODO: native script component
				

				SerializeComponent<LightComponent>(writer, entity, "LightComponent", scope (component) =>
				{
					SceneLight light = component.SceneLight;

					Serialize.Value(writer, "LightType", light.LightType);

					Serialize.Value(writer, "Illuminance", light.Illuminance);

					Serialize.Value(writer, "Color", light.Color);
				});
			}

			writer.EntryEnd();*/
		}

		static Result<void> DeserializeComponent<T>(BonReader reader, Entity entity, delegate Result<void>(T* component) deserialize) where T : struct, new
		{
			Try!(reader.ObjectBlock());
			
			T* component;

			if (entity.HasComponent<T>())
				component = entity.GetComponent<T>();
			else
				component = entity.AddComponent<T>();

			Try!(deserialize(component));

			Try!(reader.ObjectBlockEnd());

			return .Ok;
		}

		public bool DeserializeRuntime(StringView filePath)
		{
			Runtime.NotImplemented();
		}
	}
}
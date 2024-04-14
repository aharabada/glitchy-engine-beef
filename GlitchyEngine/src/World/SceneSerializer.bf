using Bon;
using Bon.Integrated;
using System;
using System.Reflection;
using System.IO;
using GlitchyEngine.Math;
using GlitchyEngine.Core;
using System.Collections;
using GlitchyEngine.Renderer;
using GlitchyEngine.Content;
using GlitchyEngine.Scripting;
using GlitchyEngine.Serialization;
using GlitchyEngine.World.Components;

namespace GlitchyEngine.World;

using internal GlitchyEngine.World;

class SceneSerializer
{
	private const int FileVersion = 1;

	private Scene _scene;

	// Maps from ParentID to ChildEntity
	private Dictionary<UUID, Entity> _parentIdToChild;

	private List<(Entity Entity, UUID ParentId)> _entitiesMissingParent;
	
	// Maps from ID in the prefab file to the actual ID in the scene.
	private Dictionary<UUID, UUID> _fileToSceneId;

	private append ScriptInstanceSerializer _scriptSerializer = .(); //Dictionary<UUID, SerializedObject> _serializedObjects ~ DeleteDictionaryAndValues!(_);

	private HashSet<UUID> _objectsNotWritten;

	private int _fileVersion;

	public ScriptInstanceSerializer ScriptSerializer => _scriptSerializer;

	public this(Scene scene)
	{
		_scene = scene;
	}

	public void Serialize(StringView filePath)
	{
		Debug.Profiler.ProfileResourceFunction!();

		_scriptSerializer.SerializeScriptInstances();

		_objectsNotWritten = new .(_scriptSerializer.SerializedObjectCount);

		for (UUID key in _scriptSerializer.SerializedObjects.Keys)
		{
			_objectsNotWritten.Add(key);
		}

		String buffer = scope String();
		let writer = scope BonWriter(buffer, true);
		var length = Serialize.Start(writer);

		gBonEnv.serializeFlags |= .IncludeDefault | .Verbose;

		using (writer.ObjectBlock())
		{
			Serialize.Value(writer, "Version", FileVersion);

			writer.Identifier("Entities");

			using (writer.ArrayBlock())
			{
				for (EcsEntity e in _scene._ecsWorld.Enumerate())
				{
					Entity entity = .(e, _scene);

					if (entity.EditorFlags.HasFlag(.DontSave))
						continue;

					SerializeEntity(writer, entity);
				}
			}

			writer.EntryEnd();

			writer.Identifier("ReferencedObjects");

			// Write all objects that don't belong to an entity. (referenced Arrays, Classes, etc...)
			using (writer.ArrayBlock())
			{
				for (UUID id in _objectsNotWritten)
				{
					SerializedObject object = _scriptSerializer.GetSerializedObject(id);

					if (object.IsStatic)
						continue;

					Serialize.Value(writer, object);
				}
			}

			writer.EntryEnd();

			writer.Identifier("StaticFields");

			// Write all objects that don't belong to an entity. (referenced Arrays, Classes, etc...)
			using (writer.ArrayBlock())
			{
				for (UUID id in _objectsNotWritten)
				{
					SerializedObject object = _scriptSerializer.GetSerializedObject(id);

					if (!object.IsStatic || object.Fields.Count == 0)
						continue;

					Serialize.Value(writer, object);
				}
			}

			writer.EntryEnd();
		}

		Serialize.End(writer, length);

		delete _objectsNotWritten;

		String targetDirectory = Path.GetDirectoryPath(filePath, .. scope String());
		Directory.CreateDirectory(targetDirectory);

		File.WriteAllText(filePath, buffer);
	}

	void SerializeEntity(BonWriter writer, Entity entity)
	{
		writer.EntryStart();

		using (writer.ObjectBlock())
		{
			Serialize.Value(writer, "Id", entity.UUID);
			
			SerializeComponent<NameComponent>(writer, entity, "NameComponent", scope (component) =>
			{
				Serialize.Value(writer, "Name", component.Name);
			});

			SerializeComponent<SpriteRendererComponent>(writer, entity, "SpriteRendererComponent", scope (component) =>
			{
				Serialize.Value(writer, "Color", component.Color);
				Serialize.Value(writer, "Sprite", component.Sprite);
				Serialize.Value(writer, "UvTransform", component.UvTransform);
			});
			SerializeComponent<CircleRendererComponent>(writer, entity, "CircleRendererComponent", scope (component) =>
			{
				Serialize.Value(writer, "Color", component.Color);
				Serialize.Value(writer, "InnerRadius", component.InnerRadius);
				Serialize.Value(writer, "Sprite", component.Sprite);
				Serialize.Value(writer, "UvTransform", component.UvTransform);
			});

			SerializeComponent<TransformComponent>(writer, entity, "TransformComponent", scope (component) =>
			{
				// TODO: Use GUIDs
				if (component.Parent != .InvalidEntity)
				{
					Entity parent = Entity(component.Parent, _scene);
					Serialize.Value(writer, "ParentId", parent.UUID);
				}

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
			
			SerializeComponent<LightComponent>(writer, entity, "LightComponent", scope (component) =>
			{
				SceneLight light = component.SceneLight;

				Serialize.Value(writer, "LightType", light.LightType);

				Serialize.Value(writer, "Illuminance", light.Illuminance);

				Serialize.Value(writer, "Color", light.Color);
			});

			SerializeComponent<Rigidbody2DComponent>(writer, entity, "Rigidbody2D", scope (component) =>
			{
				Serialize.Value(writer, "BodyType", component.BodyType);

				Serialize.Value(writer, "FixedRotation", component.FixedRotation);

				Serialize.Value(writer, "GravityScale", component.GravityScale);
			});

			SerializeComponent<BoxCollider2DComponent>(writer, entity, "BoxCollider2D", scope (component) =>
			{
				Serialize.Value(writer, "Offset", component.Offset);
				Serialize.Value(writer, "Size", component.Size);

				Serialize.Value(writer, "Density", component.Density);
				Serialize.Value(writer, "Friction", component.Friction);
				Serialize.Value(writer, "Restitution", component.Restitution);
				Serialize.Value(writer, "RestitutionThreshold", component.RestitutionThreshold);
			});

			SerializeComponent<CircleCollider2DComponent>(writer, entity, "CircleCollider2D", scope (component) =>
			{
				Serialize.Value(writer, "Offset", component.Offset);
				Serialize.Value(writer, "Radius", component.Radius);

				Serialize.Value(writer, "Density", component.Density);
				Serialize.Value(writer, "Friction", component.Friction);
				Serialize.Value(writer, "Restitution", component.Restitution);
				Serialize.Value(writer, "RestitutionThreshold", component.RestitutionThreshold);
			});

			SerializeComponent<PolygonCollider2DComponent>(writer, entity, "PolygonCollider2D", scope (component) =>
			{
				Serialize.Value(writer, "Offset", component.Offset);
				
				Serialize.Value(writer, "Vertices", component.Vertices);
				Serialize.Value(writer, "VertexCount", component.VertexCount);

				Serialize.Value(writer, "Density", component.Density);
				Serialize.Value(writer, "Friction", component.Friction);
				Serialize.Value(writer, "Restitution", component.Restitution);
				Serialize.Value(writer, "RestitutionThreshold", component.RestitutionThreshold);
			});

			SerializeComponent<MeshComponent>(writer, entity, "MeshComponent", scope (component) =>
			{
				Serialize.Value(writer, "Mesh", component.Mesh);
			});

			SerializeComponent<MeshRendererComponent>(writer, entity, "MeshRendererComponent", scope (component) =>
			{
				Serialize.Value(writer, "Material", component.Material);
			});

			SerializeComponent<ScriptComponent>(writer, entity, "ScriptComponent", scope (component) =>
			{
				Serialize.Value(writer, "ScriptClass", component.ScriptClassName);

				if (_scriptSerializer.TryGetSerializedObject(entity.UUID, let value))
				{
					Serialize.Value(writer, "Fields", value);

					_objectsNotWritten.Remove(entity.UUID);
				}
			});

			SerializeComponent<EditorFlagsComponent>(writer, entity, "Editor", scope (component) =>
			{
				Serialize.Value(writer, "Flags", component.Flags);
			});

			SerializeComponent<TextRendererComponent>(writer, entity, "TextRenderer", scope (component) =>
			{
				Serialize.Value(writer, "IsRichText", component.IsRichText);
				Serialize.Value(writer, "Text", component.Text);
				Serialize.Value(writer, "Color", component.Color);
				Serialize.Value(writer, "FontSize", component.FontSize);
				Serialize.Value(writer, "HorizontalAlignment", component.HorizontalAlignment);
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
	
	private Result<void> DeserializeValue<T>(BonReader reader, StringView identifier, out T value, bool tryEndEntry = true, BonEnvironment env = gBonEnv)
	{
		Try!(Deserialize.Value(reader, identifier, out value, env));

		TryEndEntry(reader);

		return .Ok;
	}
	
	private static bool Check(BonReader reader, char8 token, bool consume = true)
	{
		return reader.[Friend]Check(token, consume);
	}

	private static bool TryEndEntry(BonReader reader)
	{
		if (Check(reader, ',', false))
		{
			reader.EntryEnd();
			return true;
		}

		return false;
	}

	public Result<void> Deserialize(StringView filePath, bool loadAsPrefab = false)
	{
		Debug.Profiler.ProfileResourceFunction!();

		_parentIdToChild = scope Dictionary<UUID, Entity>();
		_entitiesMissingParent = scope List<(Entity Entity, UUID ParentId)>();
		_fileToSceneId = scope Dictionary<UUID, UUID>();

		String buffer = scope String();
		File.ReadAllText(filePath, buffer);

		let reader = scope BonReader();
		Try!(reader.Setup(buffer));
		Try!(Deserialize.Start(reader));

		Try!(reader.ObjectBlock());

		_scene.Name = Path.GetFileName(filePath, .. scope .());
		
		Try!(DeserializeValue(reader, "Version", out _fileVersion));

		if (_fileVersion == 0 || _fileVersion > FileVersion)
		{
			Log.EngineLogger.Warning("The scene file either has no version or it's newer than the current editor. Deserialization might fail.");
		}

		while (reader.ObjectHasMore())
		{
			StringView identifier = Try!(reader.Identifier());

			switch (identifier)
			{
			case "Entities":
				Try!(DeserializeEntities(reader, loadAsPrefab));
			case "ReferencedObjects":
				Try!(DeserializeReferencedObjects(reader, false));
			case "StaticFields":
				Try!(DeserializeReferencedObjects(reader, true));
			default:
				Log.EngineLogger.Warning($"Encountered unexpected Identifier \"{identifier}\".");
			}

			TryEndEntry(reader);
		}

		Try!(reader.ObjectBlockEnd());

		Try!(Deserialize.End(reader));
		
		// Find parents for entities that don't have their parent yet
		for ((Entity Entity, UUID ParentId) entry in _entitiesMissingParent)
		{
			let parentResult = _scene.GetEntityByID(entry.ParentId);

			Log.EngineLogger.Assert(parentResult case .Ok, "Parent entity does not exist.");

			if (parentResult case .Ok(let parent))
			{
				entry.Entity.Parent = parent;
			}
		}

		return .Ok;
	}

	private Result<void> DeserializeEntities(BonReader reader, bool loadAsPrefab)
	{
		Try!(reader.ArrayBlock());

		while (reader.ArrayHasMore())
		{
			Try!(DeserializeEntity(reader, loadAsPrefab));

			TryEndEntry(reader);
		}

		Try!(reader.ArrayBlockEnd());

		return .Ok;
	}

	private Result<void> DeserializeReferencedObjects(BonReader reader, bool isStatic)
	{
		Try!(reader.ArrayBlock());

		while (reader.ArrayHasMore())
		{
			SerializedObject object = Try!(SerializedObject.BonDeserialize(reader, _scriptSerializer, _fileVersion, gBonEnv));

			object.IsStatic = isStatic;

			TryEndEntry(reader);
		}

		Try!(reader.ArrayBlockEnd());

		return .Ok;
	}

	/// Deserializes the next entity in the file
	/// @param reader the reader
	/// @param replaceId If false, the ID that is stored in the file will be used as ID in the scene.
	/// If true, the ID in the file will be replaced with a new id (e.g. for loading prefabs)
	private Result<void> DeserializeEntity(BonReader reader, bool newId)
	{
		mixin DeserializeAssetHandle<T>(StringView identifier) where T : Asset
		{
			Asset asset = null;

			Try!(Deserialize.Value(reader, identifier, out asset));

			if (asset != null && !(asset is T))
			{
				Log.EngineLogger.Error($"Asset {asset.Identifier} is not a {nameof(T)}.");
				return .Err;
			}

			asset?.Handle ?? .Invalid
		}

		UUID RemapId(UUID id)
		{
			if (!newId)
				return id;

			if (_fileToSceneId.TryGetValue(id, let sceneId))
				return sceneId;

			// If we remap IDs map the file Id to a random Id.
			UUID newId = UUID.Create();

			_fileToSceneId.Add(id, newId);

			return newId;
		}

		Try!(reader.ObjectBlock());

		// We must start with the Id because we need to construct the entity!
		DeserializeValue<uint64>(reader, "Id", let rawUuid);

		UUID uuid = RemapId(UUID(rawUuid));

		Entity entity = _scene.CreateEntity("", uuid);

		while(reader.ObjectHasMore())
		{
			TryEndEntry(reader);

			StringView componentIdentifier = Try!(reader.Identifier());

			switch(componentIdentifier)
			{
			case "NameComponent":
				Try!(DeserializeComponent<NameComponent>(reader, entity, scope (component) =>
				{
					Try!(Deserialize.Value<String>(reader, "Name", let name));
					component.Name = name;
					delete name;

					return .Ok;
				}));
			case "SpriteRendererComponent":
				Try!(DeserializeComponentFields<SpriteRendererComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
				{
					switch(fieldIdentifier)
					{
					case "Color":
						Try!(Deserialize.Value(reader, out component.Color));
					case "Sprite":
						Try!(Deserialize.Value(reader, out component.Sprite));
					case "UvTransform":
						Try!(Deserialize.Value(reader, out component.UvTransform));
					default:
						return false;
					}

					return true;
				}));
			case "CircleRendererComponent":
				Try!(DeserializeComponentFields<CircleRendererComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
				{
					switch(fieldIdentifier)
					{
					case "Color":
						Try!(Deserialize.Value(reader, out component.Color));
					case "InnerRadius":
						Try!(Deserialize.Value(reader, out component.InnerRadius));
					case "Sprite":
						Try!(Deserialize.Value(reader, out component.Sprite));
					case "UvTransform":
						Try!(Deserialize.Value(reader, out component.UvTransform));
					default:
						return false;
					}

					return true;
				}));
			case "TransformComponent":
				Try!(DeserializeComponentFields<TransformComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
				{
					switch(fieldIdentifier)
					{
					case "ParentId":
						UUID rawParentId;
						Try!(Deserialize.Value(reader, out rawParentId));

						UUID parentId = RemapId(rawParentId);

						var parentEntity = _scene.GetEntityByID(parentId);

						if (parentEntity case .Ok(let parent))
						{
							component.Parent = parent.Handle;
						}
						else
						{
							_entitiesMissingParent.Add((entity, parentId));
						}
					case "Position":
						Try!(Deserialize.Value(reader, out component.[Friend]_position));
					case "Rotation":
						Try!(Deserialize.Value(reader, out component.[Friend]_rotation));
					case "Scale":
						Try!(Deserialize.Value(reader, out component.[Friend]_scale));
					case "EditorEulerRotation":
						Try!(Deserialize.Value(reader, out component.[Friend]_editorRotationEuler));
					default:
						return false;
					}

					component.IsDirty = true;

					return true;
				}));
			case "CameraComponent":
				Try!(DeserializeComponentFields<CameraComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
					{
						ref SceneCamera camera = ref component.Camera;

						switch(fieldIdentifier)
						{
						case "Primary":
							Try!(Deserialize.Value(reader, out component.Primary));
						case "ProjectionType":
							Try!(Deserialize.Value(reader, out camera.[Friend]_projectionType));

						case "PerspectiveFovY":
							Try!(Deserialize.Value(reader, out camera.[Friend]_perspectiveFovY));
						case "PerspectiveNearPlane":
							Try!(Deserialize.Value(reader, out camera.[Friend]_perspectiveNearPlane));
						case "PerspectiveFarPlane":
							Try!(Deserialize.Value(reader, out camera.[Friend]_perspectiveFarPlane));

						case "OrthographicHeight":
							Try!(Deserialize.Value(reader, out camera.[Friend]_orthographicHeight));
						case "OrthographicNearPlane":
							Try!(Deserialize.Value(reader, out camera.[Friend]_orthographicNearPlane));
						case "OrthographicFarPlane":
							Try!(Deserialize.Value(reader, out camera.[Friend]_orthographicFarPlane));
						case "AspectRatio":
							Try!(Deserialize.Value(reader, out camera.[Friend]_aspectRatio));
						case "FixedAspectRatio":
							Try!(Deserialize.Value(reader, out camera.[Friend]_fixedAspectRatio));
						default:
							return false;
						}

						return true;
					}));
			case "LightComponent":
				Try!(DeserializeComponentFields<LightComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
				{
					ref SceneLight light = ref component.SceneLight;

					switch(fieldIdentifier)
					{
					case "LightType":
						Try!(Deserialize.Value(reader, out light.[Friend]_type));
					case "Illuminance":
						Try!(Deserialize.Value(reader, out light.[Friend]_illuminance));
					case "Color":
						Try!(Deserialize.Value(reader, out light.[Friend]_color));
					default:
						return false;
					}

					return true;
				}));
			case "Rigidbody2D":
				Try!(DeserializeComponentFields<Rigidbody2DComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
				{
					switch(fieldIdentifier)
					{
					case "BodyType":
						Rigidbody2DComponent.BodyType bodyType = .Static;
						Try!(Deserialize.Value(reader, out bodyType));
						component.BodyType = bodyType;
					case "FixedRotation":
						Try!(Deserialize.Value<bool>(reader, let fixedRotation));
						component.FixedRotation = fixedRotation;
					case "GravityScale":
						Try!(Deserialize.Value<float>(reader, let gravityScale));
						component.GravityScale = gravityScale;
					default:
						return false;
					}

					return true;
				}));
			case "BoxCollider2D":
				Try!(DeserializeComponentFields<BoxCollider2DComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
				{
					switch(fieldIdentifier)
					{
					case "Offset":
						Try!(Deserialize.Value(reader, out component.Offset));
					case "Size":
						Try!(Deserialize.Value(reader, out component.Size));

					case "Density":
						Try!(Deserialize.Value(reader, out component.Density));
					case "Friction":
						Try!(Deserialize.Value(reader, out component.Friction));
					case "Restitution":
						Try!(Deserialize.Value(reader, out component.Restitution));
					case "RestitutionThreshold":
						Try!(Deserialize.Value(reader, out component.RestitutionThreshold));
					default:
						return false;
					}

					return true;
				}));
			case "CircleCollider2D":
				Try!(DeserializeComponentFields<CircleCollider2DComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
				{
					switch(fieldIdentifier)
					{
					case "Offset":
						Try!(Deserialize.Value(reader, out component.Offset));
					case "Radius":
						Try!(Deserialize.Value(reader, out component.Radius));

					case "Density":
						Try!(Deserialize.Value(reader, out component.Density));
					case "Friction":
						Try!(Deserialize.Value(reader, out component.Friction));
					case "Restitution":
						Try!(Deserialize.Value(reader, out component.Restitution));
					case "RestitutionThreshold":
						Try!(Deserialize.Value(reader, out component.RestitutionThreshold));
					default:
						return false;
					}

					return true;
				}));
			case "PolygonCollider2D":
				Try!(DeserializeComponentFields<PolygonCollider2DComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
				{
					switch(fieldIdentifier)
					{
					case "Offset":
						Try!(Deserialize.Value(reader, out component.Offset));
					case "Vertices":
						Try!(Deserialize.Value(reader, out component.Vertices));
					case "VertexCount":
						Try!(Deserialize.Value(reader, out component.VertexCount));

					case "Density":
						Try!(Deserialize.Value(reader, out component.Density));
					case "Friction":
						Try!(Deserialize.Value(reader, out component.Friction));
					case "Restitution":
						Try!(Deserialize.Value(reader, out component.Restitution));
					case "RestitutionThreshold":
						Try!(Deserialize.Value(reader, out component.RestitutionThreshold));
					default:
						return false;
					}

					return true;
				}));
			case "MeshComponent":
				Try!(DeserializeComponent<MeshComponent>(reader, entity, scope (component) =>
				{
					Try!(Deserialize.Value(reader, "Mesh", out component.Mesh));

					return .Ok;
				}));
			case "MeshRendererComponent":
				Try!(DeserializeComponent<MeshRendererComponent>(reader, entity, scope (component) =>
				{
					Try!(Deserialize.Value(reader, "Material", out component.Material));

					return .Ok;
				}));
			case "ScriptComponent":
				Try!(DeserializeComponentFields<ScriptComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
				{
					switch(fieldIdentifier)
					{
					case "ScriptClass":
						Try!(Deserialize.Value<String>(reader, let scriptClassName));
						component.ScriptClassName = scriptClassName;
						delete scriptClassName;
					case "Fields":
						Try!(SerializedObject.BonDeserialize(reader, _scriptSerializer, _fileVersion, gBonEnv));
					default:
						return false;
					}

					return true;
				}));
			case "Editor":
				Try!(DeserializeComponent<EditorFlagsComponent>(reader, entity, scope (component) =>
				{
					Try!(Deserialize.Value(reader, "Flags", out component.Flags));

					return .Ok;
				}));
			case "TextRenderer":
				Try!(DeserializeComponentFields<TextRendererComponent>(reader, componentIdentifier, entity, scope (component, fieldIdentifier) =>
				{
					switch(fieldIdentifier)
					{
					case "IsRichText":
						Try!(Deserialize.Value<bool>(reader, let isRichText));
						component.IsRichText = isRichText;
					case "Text":
						Try!(Deserialize.Value<String>(reader, let text));
						component.Text = text;
						delete text;
					case "Color":
						Try!(Deserialize.Value(reader, out component.Color));
					case "FontSize":
						Try!(Deserialize.Value(reader, out component.FontSize));
					case "HorizontalAlignment":
						Try!(Deserialize.Value(reader, out component.HorizontalAlignment));
					default:
						return false;
					}

					return true;
				}));
			default:
				Log.EngineLogger.Error($"Unknown component type \"{componentIdentifier}\" in entity {entity.UUID}");
				return .Err;
			}
		}

		Try!(reader.ObjectBlockEnd());

		return .Ok;
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

	static Result<void> DeserializeComponentFields<T>(BonReader reader, StringView prettyComponentName, Entity entity, delegate Result<bool>(T* component, StringView identifier) deserializeField) where T : struct, new
	{
		Try!(reader.ObjectBlock());
		
		T* component;

		if (entity.HasComponent<T>())
			component = entity.GetComponent<T>();
		else
			component = entity.AddComponent<T>();

		while(reader.ObjectHasMore())
		{
			StringView fieldIdentifier = Try!(reader.Identifier());
			
			if (!Try!(deserializeField(component, fieldIdentifier)))
			{
				Log.EngineLogger.Error($"Unknown identifier \"{fieldIdentifier}\" in component \"{prettyComponentName}\" of entity {entity.UUID}");
				return .Err;
			}

			TryEndEntry(reader);
		}

		Try!(reader.ObjectBlockEnd());

		return .Ok;
	}

	public bool DeserializeRuntime(StringView filePath)
	{
		Runtime.NotImplemented();
	}
}

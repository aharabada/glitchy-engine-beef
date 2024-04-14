using Mono;
using System;
using GlitchLog;
using System.Reflection;
using GlitchyEngine.Events;
using GlitchyEngine.Math;
using GlitchyEngine.World;
using GlitchyEngine.Core;
using System.Collections;
using Box2D;
using GlitchyEngine.Scripting;
using GlitchyEngine.Serialization;
using GlitchyEngine.Editor;
using GlitchyEngine.World.Components;
using static GlitchyEngine.Renderer.Text.FontRenderer;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

class MessageOrigin
{
	private String _fileName;
	private int _lineNumber;

	public StringView FileName => _fileName;
	public int LineNumber => _lineNumber;

	[AllowAppend]
	public this(StringView fileName, int lineNumber)
	{
		String file = append String(fileName);

		_fileName = file;
		_lineNumber = lineNumber;
	}
}

static class ScriptGlue
{
	private static Dictionary<MonoType*, function void(Entity entityId)> s_AddComponentMethods = new .() ~ delete _;
	private static Dictionary<MonoType*, function bool(Entity entityId)> s_HasComponentMethods = new .() ~ delete _;
	private static Dictionary<MonoType*, function void(Entity entityId)> s_RemoveComponentMethods = new .() ~ delete _;

	struct RegisterCallAttribute : Attribute
	{
		public String MethodName;

		public this(String methodName)
		{
			MethodName = methodName;
		}
	}

	/* Adding this attribute to a method will log method entry and returned Result<T> errors */
	[AttributeUsage(.Method)]
	struct RegisterMethodAttribute : Attribute, IOnMethodInit
	{
	    [Comptime]
	    public void OnMethodInit(MethodInfo method, Self* prev)
	    {
	        for (var methodInfo in typeof(ScriptGlue).GetMethods(.Static))
			{
				if (methodInfo.GetCustomAttribute<RegisterCallAttribute>() case .Ok(let attribute))
				{
					String functionType = scope $"{methodInfo.ReturnType}({methodInfo.GetParamsDecl(.. scope .())})";

					String line = scope $"RegisterCall<function {functionType}>(\"{attribute.MethodName}\", => {methodInfo.Name});\n";

					Compiler.EmitMethodEntry(method, line);
				}
			}
	    }
	}

	public static void Init()
	{
		RegisterCalls();

		RegisterMathFunctions();
	}

	public static void RegisterManagedComponents()
	{
		Debug.Profiler.ProfileFunction!();

		s_AddComponentMethods.Clear();
		s_HasComponentMethods.Clear();
		s_RemoveComponentMethods.Clear();

		RegisterComponent<TransformComponent>("GlitchyEngine.Core.Transform");
		RegisterComponent<Rigidbody2DComponent>("GlitchyEngine.Physics.Rigidbody2D");
		RegisterComponent<CameraComponent>("GlitchyEngine.Core.Camera");
		RegisterComponent<CircleRendererComponent>("GlitchyEngine.Graphics.CircleRenderer");
		RegisterComponent<TextRendererComponent>("GlitchyEngine.Graphics.Text.TextRenderer");
	}

	[RegisterMethod]
	private static void RegisterCalls()
	{
	}

	private static void RegisterComponent<T>(StringView cSharpClassName = "") where T : struct, new
	{
		String className;

		if (cSharpClassName.IsWhiteSpace)
		{
			className = scope:: $"GlitchyEngine.";
			typeof(T).GetName(className);
		}
		else
		{
			className = scope:: String(cSharpClassName);
		}

		className.EnsureNullTerminator();

		MonoType* managedType = Mono.mono_reflection_type_from_name(className.CStr(), ScriptEngine.[Friend]s_CoreAssemblyImage);
		
		if (managedType != null)
		{
			s_AddComponentMethods[managedType] = (entity) => entity.AddComponent<T>();
			s_HasComponentMethods[managedType] = (entity) => entity.HasComponent<T>();
			s_RemoveComponentMethods[managedType] = (entity) => entity.RemoveComponent<T>();
		}
		else
		{
			Log.EngineLogger.AssertDebug(managedType != null, scope $"No C# component with name \"{className}\" found for Beef type \"{typeof(T)}\"");
		}
	}

	/// Gets the entity with the given id. Throws a mono exception, if the entity doesn't exist.
	static Entity GetEntitySafe(UUID entityId)
	{
		Result<Entity> foundEntity = ScriptEngine.Context.GetEntityByID(entityId);

		if (foundEntity case .Ok(let entity))
		{
			return foundEntity;
		}
		else
		{
			ThrowArgumentException(null, "The entity doesn't exist or was deleted.");
		}
	}

	/// Gets the component of the specified type that is attached to the given entity. Or null, if the entity doesn't exist or doesn't have the specified component.
	static T* GetComponentSafe<T>(UUID entityId) where T: struct, new
	{
		Result<Entity> foundEntity = ScriptEngine.Context.GetEntityByID(entityId);

		if (foundEntity case .Ok(let entity))
		{
			if (entity.TryGetComponent<T>(let component))
			{
				return component;
			}
			else
			{
				ThrowArgumentException(null, scope $"The entity has no component of type {typeof(T)} or it was deleted.");
			}
		}
		else
		{
			ThrowArgumentException(null, "The entity doesn't exist or was deleted.");
		}
	}

	/// Gets the component of the specified type that is attached to the given entity. Or null, if the entity doesn't exist or doesn't have the specified component.
	static bool TryGetComponentSafe<T>(UUID entityId, out T* component) where T: struct, new
	{
		Result<Entity> foundEntity = ScriptEngine.Context.GetEntityByID(entityId);

		if (foundEntity case .Ok(let entity))
		{
			if (entity.TryGetComponent<T>(out component))
			{
				return true;
			}
			else
			{
				Log.ClientLogger.Error($"Entity {entityId} has no {nameof(T)}.");
			}
		}
		else
		{
			Log.ClientLogger.Error($"No entity with ID {entityId} found.");
		}

		component = null;
		return false;
	}
	
	/// Gets the entity. Returns true, if the entity was found.
	static bool TryGetEntitySafe(UUID entityId, out Entity entity)
	{
		entity = default;

		Result<Entity> foundEntity = ScriptEngine.Context.GetEntityByID(entityId);

		if (foundEntity case .Ok(out entity))
		{
			return true;
		}

		Log.ClientLogger.Error($"No entity with ID {entityId} found.");
		return false;
	}


#region Exception Helpers

	/// Throws an argument exception.
	[NoReturn]
	static void ThrowArgumentException(char8* argument, char8* message)
	{
		MonoException* exception = Mono.mono_get_exception_argument(argument, message);
		Mono.mono_raise_exception(exception);
	}

#endregion
	
#region Log

	[RegisterCall("ScriptGlue::Log_LogMessage")]
	static void Log_LogMessage(int32 logLevel, MonoString* message, MonoString* fileName, int lineNumber)
	{
		char8* utfMessage = Mono.mono_string_to_utf8(message);
		
		String escapedMessage = scope String(StringView(utfMessage));

		escapedMessage.Replace("{", "{{");
		escapedMessage.Replace("}", "}}");

		if (fileName != null)
		{
			char8* utfFileName = Mono.mono_string_to_utf8(fileName);

			MessageOrigin messageOrigin = new MessageOrigin(StringView(utfFileName), lineNumber);


			Log.ClientLogger.Log((LogLevel)logLevel, escapedMessage, messageOrigin);

			Mono.mono_free(utfFileName);
		}
		else
		{
			Log.ClientLogger.Log((LogLevel)logLevel, escapedMessage);
		}

		Mono.mono_free(utfMessage);
	}

	[RegisterCall("ScriptGlue::Log_LogException")]
	static void Log_LogException(MonoException* exception, UUID entityId)
	{
		ScriptEngine.HandleMonoException(exception, entityId);
	}

#endregion

#region Input

	[RegisterCall("Input::IsKeyPressed")]
	static bool Input_IsKeyPressed(Key key) => Input.IsKeyPressed(key);

	[RegisterCall("Input::IsKeyReleased")]
	static bool Input_IsKeyReleased(Key key) => Input.IsKeyReleased(key);
	
	[RegisterCall("Input::IsKeyToggled")]
	static bool Input_IsKeyToggled(Key key) => Input.IsKeyToggled(key);

	[RegisterCall("Input::IsKeyPressing")]
	static bool Input_IsKeyPressing(Key key) => Input.IsKeyPressing(key);

	[RegisterCall("Input::IsKeyReleasing")]
	static bool Input_IsKeyReleasing(Key key) => Input.IsKeyReleasing(key);

	
	[RegisterCall("Input::IsMouseButtonPressed")]
	static bool Input_IsMouseButtonPressed(MouseButton mouseButton) => Input.IsMouseButtonPressed(mouseButton);

	[RegisterCall("Input::IsMouseButtonReleased")]
	static bool Input_IsMouseButtonReleased(MouseButton mouseButton) => Input.IsMouseButtonReleased(mouseButton);

	[RegisterCall("Input::IsMouseButtonPressing")]
	static bool Input_IsMouseButtonPressing(MouseButton mouseButton) => Input.IsMouseButtonPressing(mouseButton);

	[RegisterCall("Input::IsMouseButtonReleasing")]
	static bool Input_IsMouseButtonReleasing(MouseButton mouseButton) => Input.IsMouseButtonReleasing(mouseButton);

#endregion Input

#region Scene/Entity stuff

	[RegisterCall("ScriptGlue::Entity_Create")]
	static void Entity_Create(MonoObject* scriptInstance, MonoString* monoEntityName, MonoArray* componentTypes, out UUID entityId)
	{
		char8* entityName = Mono.mono_string_to_utf8(monoEntityName);
		
		Entity entity = ScriptEngine.Context.CreateEntity(StringView(entityName));

		Mono.mono_free(entityName);

		entityId = entity.UUID;

		// TODO: Script instance

		if (componentTypes != null)
		{
			Entity_AddComponents(entityId, componentTypes);
		}
	}

	[RegisterCall("ScriptGlue::Entity_Destroy")]
	static void Entity_Destroy(UUID entityId)
	{
		Entity entity = GetEntitySafe(entityId);
		ScriptEngine.Context.DestroyEntityDeferred(entity);
	}

	[RegisterCall("ScriptGlue::Entity_CreateInstance")]
	static void Entity_CreateInstance(UUID entityId, out UUID newEntityId)
	{
		Entity entity = GetEntitySafe(entityId);
		Entity newEntity = ScriptEngine.Context.CreateInstance(entity);

		newEntityId = newEntity.UUID;
	}
	
	[RegisterCall("ScriptGlue::Entity_AddComponents")]
	static void Entity_AddComponents(UUID entityId, MonoArray* componentTypes)
	{
		if (componentTypes == null)
			return;

		uint length = Mono.mono_array_length(componentTypes);
		for (uint i < length)
		{
			MonoReflectionType* reflectionType = Mono.mono_array_get<MonoReflectionType*>(componentTypes, i);

			if (reflectionType != null)
				Entity_AddComponent(entityId, reflectionType);
		}
	}

	[RegisterCall("ScriptGlue::Entity_AddComponent")]
	static void Entity_AddComponent(UUID entityId, MonoReflectionType* componentType)
	{
		MonoType* type = Mono.mono_reflection_type_get_type(componentType);

		Entity entity = GetEntitySafe(entityId);
		if (s_AddComponentMethods.TryGetValue(type, let addMethod))
			addMethod(entity);
		else
			Log.EngineLogger.AssertDebug(false, "No managed component with the given type registered.");
	}
	
	[RegisterCall("ScriptGlue::Entity_HasComponent")]
	static bool Entity_HasComponent(UUID entityId, MonoReflectionType* componentType)
	{
		MonoType* type = Mono.mono_reflection_type_get_type(componentType);

		Result<Entity> foundEntity = ScriptEngine.Context.GetEntityByID(entityId);

		if (foundEntity case .Ok(let entity))
		{
			if (s_HasComponentMethods.TryGetValue(type, let hasMethod))
				return hasMethod(entity);
		}
		else
		{
			Log.ClientLogger.Warning($"No entity found with the given id \"{entityId}\".");

			return false;
		}

		Log.EngineLogger.AssertDebug(false, "No managed component with the given type registered.");

		return false;
	}
	
	[RegisterCall("ScriptGlue::Entity_RemoveComponent")]
	static void Entity_RemoveComponent(UUID entityId, MonoReflectionType* componentType)
	{
		MonoType* type = Mono.mono_reflection_type_get_type(componentType);

		Entity entity = GetEntitySafe(entityId);
		if (s_RemoveComponentMethods.TryGetValue(type, let removeMethod))
			removeMethod(entity);
		else
			Log.EngineLogger.AssertDebug(false, "No managed component with the given type registered.");
	}
	
	[RegisterCall("ScriptGlue::Entity_FindEntityWithName")]
	static void Entity_FindEntityWithName(MonoString* monoName, UUID* outUuid)
	{
		*outUuid = UUID(0);

		char8* entityName = Mono.mono_string_to_utf8(monoName);

		StringView nameString = StringView(entityName);

		Result<Entity> entityResult = ScriptEngine.Context.GetEntityByName(nameString);

		Mono.mono_free(entityName);

		if (entityResult case .Ok(let entity))
			*outUuid = entity.UUID;
	}

	[RegisterCall("ScriptGlue::Entity_GetScriptInstance")]
	static void Entity_GetScriptInstance(UUID entityId, out MonoObject* instance)
	{
		instance = ScriptEngine.GetManagedInstance(entityId);
	}

	[RegisterCall("ScriptGlue::Entity_SetScript")]
	static MonoObject* Entity_SetScript(UUID entityId, MonoReflectionType* scriptType)
	{
		Entity entity = GetEntitySafe(entityId);

		ScriptComponent* scriptComponent = null;

		if (!entity.HasComponent<ScriptComponent>())
		{
			scriptComponent = entity.AddComponent<ScriptComponent>();
		}
		else
		{
			scriptComponent = entity.GetComponent<ScriptComponent>();
		}

		if (scriptComponent.Instance != null)
			ScriptEngine.Context.DestroyScriptDeferred(scriptComponent.Instance, false);

		scriptComponent.Instance = null;

		MonoType* type = Mono.mono_reflection_type_get_type(scriptType);

		scriptComponent.ScriptClassName = StringView(Mono.mono_type_full_name(type));
		
		// Initializes the created instance
		// TODO: this returns false, if no script with ScriptClassName exists, we have to handle this case correctly I think.
		ScriptEngine.InitializeInstance(entity, scriptComponent);

		return scriptComponent.Instance.MonoInstance;
	}
	
	[RegisterCall("ScriptGlue::Entity_RemoveScript")]
	static void Entity_RemoveScript(UUID entityId)
	{
		ScriptComponent* scriptComponent = GetComponentSafe<ScriptComponent>(entityId);

		ScriptEngine.Context.DestroyScriptDeferred(scriptComponent.Instance, true);
	}
	
	[RegisterCall("ScriptGlue::Entity_GetName")]
    static MonoString* Entity_GetName(UUID entityId)
	{
		Result<Entity> foundEntity = ScriptEngine.Context.GetEntityByID(entityId);

		if (foundEntity case .Ok(let entity))
		{
			MonoString* name = Mono.mono_string_new_len(ScriptEngine.[Friend]s_AppDomain, entity.Name.Ptr, (.)entity.Name.Length);

			return name;
		}

		return null;
	}
    
	[RegisterCall("ScriptGlue::Entity_SetName")]
    static void Entity_SetName(UUID entityId, MonoString* name)
	{
		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);

		char8* rawName = Mono.mono_string_to_utf8(name);

		entity.Name = StringView(rawName);

		Mono.mono_free(rawName);
	}
	
	[RegisterCall("ScriptGlue::Entity_GetEditorFlags")]
    static void Entity_GetEditorFlags(UUID entityId, out EditorFlags editorFlags)
	{
		editorFlags = .Default;
#if GE_EDITOR
		if (TryGetEntitySafe(entityId, let entity))
			editorFlags = entity.EditorFlags;
#endif
	}
	
	[RegisterCall("ScriptGlue::Entity_SetEditorFlags")]
    static void Entity_SetEditorFlags(UUID entityId, EditorFlags editorFlags)
	{
#if GE_EDITOR
		if (TryGetEntitySafe(entityId, let entity))
			entity.EditorFlags = editorFlags;
#endif
	}

#endregion

#region TransformComponent

	[RegisterCall("ScriptGlue::Transform_GetParent")]
	static void Transform_GetParent(UUID entityId, out UUID parentId)
	{
		Entity entity = GetEntitySafe(entityId);

		parentId = entity.Parent?.UUID ?? .Zero;
	}

	[RegisterCall("ScriptGlue::Transform_SetParent")]
	static void Transform_SetParent(UUID entityId, in UUID parentId)
	{
		Entity entity = GetEntitySafe(entityId);

		Entity? parent = GetEntitySafe(parentId);

		entity.Parent = parent;
	}
	
	[RegisterCall("ScriptGlue::Transform_GetTranslation")]
	static void Transform_GetTranslation(UUID entityId, out float3 translation)
	{
		Entity entity = GetEntitySafe(entityId);

		translation = entity.Transform.Position;
	}

	[RegisterCall("ScriptGlue::Transform_SetTranslation")]
	static void Transform_SetTranslation(UUID entityId, in float3 translation)
	{
		Entity entity = GetEntitySafe(entityId);

		entity.Transform.Position = translation;

		// if necessary reposition Rigidbody2D
		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetPosition(translation.XY);
		}
		// TODO: we need to handle repositioning of colliders that are children of the entity with rigidbody...
	}

	[RegisterCall("ScriptGlue::Transform_GetWorldTranslation")]
	static void Transform_GetWorldTranslation(UUID entityId, out float3 translationWorld)
	{
		Entity entity = GetEntitySafe(entityId);

		TransformComponent* transform = entity.Transform;

		translationWorld = transform.WorldTransform.Translation; //(float4(entity.Transform.Position, 1.0f) * entity.Transform.WorldTransform).XYZ;
	}

	[RegisterCall("ScriptGlue::Transform_SetWorldTranslation")]
	static void Transform_SetWorldTranslation(UUID entityId, in float3 translation)
	{
		Log.ClientLogger.Warning("Transform_SetWorldTranslation is not implemented!");

		// Entity entity = GetEntitySafe(entityId);

		// entity.Transform.Position = translation;

		// // if necessary reposition Rigidbody2D
		// if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		// {
		// 	rigidbody2D.SetPosition(translation.XY);
		// }
		// TODO: we need to handle repositioning of colliders that are children of the entity with rigidbody...
	}

	[RegisterCall("ScriptGlue::Transform_TransformPointToWorld")]
	static void Transform_TransformPointToWorld(UUID entityId, float3 point, out float3 pointWorld)
	{
		Entity entity = GetEntitySafe(entityId);

		float3 localPoint = entity.Transform.Position;

		pointWorld = (float4(localPoint, 1.0f) * entity.Transform.WorldTransform).XYZ;
	}
	
	[RegisterCall("ScriptGlue::Transform_GetRotation")]
	static void Transform_GetRotation(UUID entityId, out Quaternion rotation)
	{
		Entity entity = GetEntitySafe(entityId);

		rotation = entity.Transform.Rotation;
	}

	[RegisterCall("ScriptGlue::Transform_SetRotation")]
	static void Transform_SetRotation(UUID entityId, in Quaternion rotation)
	{
		Entity entity = GetEntitySafe(entityId);
		
		entity.Transform.Rotation = rotation;

		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetAngle(entity.Transform.RotationEuler.Z);
		}
		// TODO: When rotating around the X- or Y-axis we need to deform and reposition the colliders accordingly...
	}
	
	[RegisterCall("ScriptGlue::Transform_GetRotationEuler")]
	static void Transform_GetRotationEuler(UUID entityId, out float3 rotationEuler)
	{
		Entity entity = GetEntitySafe(entityId);

		rotationEuler = entity.Transform.RotationEuler;
	}

	[RegisterCall("ScriptGlue::Transform_SetRotationEuler")]
	static void Transform_SetRotationEuler(UUID entityId, in float3 rotationEuler)
	{
		Entity entity = GetEntitySafe(entityId);
		
		entity.Transform.RotationEuler = rotationEuler;

		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetAngle(rotationEuler.Z);
		}
	}

	[Packed]
	struct AxisAngle
	{
		public float3 Axis;
		public float Angle;

		public this((float3 Axis, float Angle) axisAngle)
		{
			Axis = axisAngle.Axis;
			Angle = axisAngle.Angle;
		}
	}

	[RegisterCall("ScriptGlue::Transform_GetRotationAxisAngle")]
	static void Transform_GetRotationAxisAngle(UUID entityId, out AxisAngle rotationAxisAngle)
	{
		Entity entity = GetEntitySafe(entityId);

		rotationAxisAngle = AxisAngle(entity.Transform.RotationAxisAngle);
	}

	[RegisterCall("ScriptGlue::Transform_SetRotationAxisAngle")]
	static void Transform_SetRotationAxisAngle(UUID entityId, AxisAngle rotationAxisAngle)
	{
		Entity entity = GetEntitySafe(entityId);
		
		entity.Transform.RotationAxisAngle = (rotationAxisAngle.Axis, rotationAxisAngle.Angle);

		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetAngle(entity.Transform.RotationEuler.Z);
		}
	}

	[RegisterCall("ScriptGlue::Transform_GetScale")]
	static void Transform_GetScale(UUID entityId, out float3 scale)
	{
		Entity entity = GetEntitySafe(entityId);

		scale = entity.Transform.Scale;
	}

	[RegisterCall("ScriptGlue::Transform_SetScale")]
	static void Transform_SetScale(UUID entityId, float3 scale)
	{
		Entity entity = GetEntitySafe(entityId);
		
		entity.Transform.Scale = scale;

		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			// TODO: we need to scale and reposition the colliders, this is a mess...
		}
	}

#endregion TransformComponent

#region Rigidbody2D
	
	[RegisterCall("ScriptGlue::Rigidbody2D_ApplyForce")]
	static void Rigidbody2D_ApplyForce(UUID entityId, in float2 force, in float2 point, bool wakeUp)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		Box2D.Body.ApplyForce(rigidBody.[Friend]RuntimeBody, force, point, wakeUp);
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_ApplyForceToCenter")]
	static void Rigidbody2D_ApplyForceToCenter(UUID entityId, in float2 force, bool wakeUp)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		Box2D.Body.ApplyForceToCenter(rigidBody.[Friend]RuntimeBody, force, wakeUp);
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_SetPosition")]
	static void Rigidbody2D_SetPosition(UUID entityId, in float2 position)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetPosition(position);
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_GetPosition")]
	static void Rigidbody2D_GetPosition(UUID entityId, out float2 position)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		position = rigidBody.GetPosition();
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_SetRotation")]
	static void Rigidbody2D_SetRotation(UUID entityId, in float rotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetAngle(rotation);
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_GetRotation")]
	static void Rigidbody2D_GetRotation(UUID entityId, out float rotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rotation = rigidBody.GetAngle();
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_GetLinearVelocity")]
	static void Rigidbody2D_GetLinearVelocity(UUID entityId, out float2 velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		velocity = rigidBody.GetLinearVelocity();
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_SetLinearVelocity")]
	static void Rigidbody2D_SetLinearVelocity(UUID entityId, in float2 velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetLinearVelocity(velocity);
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_GetAngularVelocity")]
	static void Rigidbody2D_GetAngularVelocity(UUID entityId, out float velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		velocity = rigidBody.GetAngularVelocity();
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_SetAngularVelocity")]
	static void Rigidbody2D_SetAngularVelocity(UUID entityId, in float velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetAngularVelocity(velocity);
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_GetBodyType")]
	static void Rigidbody2D_GetBodyType(UUID entityId, out Rigidbody2DComponent.BodyType bodyType)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		bodyType = rigidBody.BodyType;
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_SetBodyType")]
	static void Rigidbody2D_SetBodyType(UUID entityId, in Rigidbody2DComponent.BodyType bodyType)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.BodyType = bodyType;
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_IsFixedRotation")]
	static void Rigidbody2D_IsFixedRotation(UUID entityId, out bool isFixedRotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		isFixedRotation = rigidBody.FixedRotation;
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_SetFixedRotation")]
	static void Rigidbody2D_SetFixedRotation(UUID entityId, in bool isFixedRotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.FixedRotation = isFixedRotation;
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_GetGravityScale")]
	static void Rigidbody2D_GetGravityScale(UUID entityId, out float gravityScale)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		gravityScale = rigidBody.GravityScale;
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_SetGravityScale")]
	static void Rigidbody2D_SetGravityScale(UUID entityId, in float gravityScale)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.GravityScale = gravityScale;
	}

#endregion Rigidbody2D

#region Camera

	[RegisterCall("ScriptGlue::Camera_GetProjectionType")]
	static void Camera_GetProjectionType(UUID entityId, out SceneCamera.ProjectionType projectionType)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		projectionType = camera.Camera.ProjectionType;
	}
	
	[RegisterCall("ScriptGlue::Camera_SetProjectionType")]
	static void Camera_SetProjectionType(UUID entityId, in SceneCamera.ProjectionType projectionType)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.ProjectionType = projectionType;
	}

	[RegisterCall("ScriptGlue::Camera_GetPerspectiveFovY")]
	static void Camera_GetPerspectiveFovY(UUID entityId, out float fovY)
	{
	    CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		fovY = camera.Camera.PerspectiveFovY;
	}

	[RegisterCall("ScriptGlue::Camera_SetPerspectiveFovY")]
	static void Camera_SetPerspectiveFovY(UUID entityId, float fovY)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.PerspectiveFovY = fovY;
	}

	[RegisterCall("ScriptGlue::Camera_GetPerspectiveNearPlane")]
	static void Camera_GetPerspectiveNearPlane(UUID entityId, out float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		nearPlane = camera.Camera.PerspectiveNearPlane;
	}

	[RegisterCall("ScriptGlue::Camera_SetPerspectiveNearPlane")]
	static void Camera_SetPerspectiveNearPlane(UUID entityId, float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.PerspectiveNearPlane = nearPlane;
	}

	[RegisterCall("ScriptGlue::Camera_GetPerspectiveFarPlane")]
	static void Camera_GetPerspectiveFarPlane(UUID entityId, out float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		farPlane = camera.Camera.PerspectiveFarPlane;
	}

	[RegisterCall("ScriptGlue::Camera_SetPerspectiveFarPlane")]
	static void Camera_SetPerspectiveFarPlane(UUID entityId, float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.PerspectiveFarPlane = farPlane;
	}

	[RegisterCall("ScriptGlue::Camera_GetOrthographicHeight")]
	static void Camera_GetOrthographicHeight(UUID entityId, out float height)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		height = camera.Camera.OrthographicHeight;
	}

	[RegisterCall("ScriptGlue::Camera_SetOrthographicHeight")]
	static void Camera_SetOrthographicHeight(UUID entityId, float height)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.OrthographicHeight = height;
	}

	[RegisterCall("ScriptGlue::Camera_SetOrthographicNearPlane")]
	static void Camera_SetOrthographicNearPlane(UUID entityId, float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.OrthographicNearPlane = nearPlane;
	}

	[RegisterCall("ScriptGlue::Camera_GetOrthographicNearPlane")]
	static void Camera_GetOrthographicNearPlane(UUID entityId, out float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		nearPlane = camera.Camera.OrthographicNearPlane;
	}

	[RegisterCall("ScriptGlue::Camera_SetOrthographicFarPlane")]
	static void Camera_SetOrthographicFarPlane(UUID entityId, float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.OrthographicFarPlane = farPlane;
	}

	[RegisterCall("ScriptGlue::Camera_GetOrthographicFarPlane")]
	static void Camera_GetOrthographicFarPlane(UUID entityId, out float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		farPlane = camera.Camera.OrthographicFarPlane;
	}

	[RegisterCall("ScriptGlue::Camera_SetAspectRatio")]
	static void Camera_SetAspectRatio(UUID entityId, float aspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.AspectRatio = aspectRatio;
	}

	[RegisterCall("ScriptGlue::Camera_GetAspectRatio")]
	static void Camera_GetAspectRatio(UUID entityId, out float aspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		aspectRatio = camera.Camera.AspectRatio;
	}

	[RegisterCall("ScriptGlue::Camera_SetFixedAspectRatio")]
	static void Camera_SetFixedAspectRatio(UUID entityId, bool fixedAspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.FixedAspectRatio = fixedAspectRatio;
	}

	[RegisterCall("ScriptGlue::Camera_GetFixedAspectRatio")]
	static void Camera_GetFixedAspectRatio(UUID entityId, out bool fixedAspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		fixedAspectRatio = camera.Camera.FixedAspectRatio;
	}

#endregion

#region Physics2D

	// TODO: We need a wrapper class!

	[RegisterCall("ScriptGlue::Physics2D_GetGravity")]
	static void Physics2D_GetGravity(out float2 gravity)
	{
		Scene scene = ScriptEngine.Context;

		gravity = scene.Physics2DSettings.Gravity;
	}

	[RegisterCall("ScriptGlue::Physics2D_SetGravity")]
	static void Physics2D_SetGravity(in float2 gravity)
	{
		Scene scene = ScriptEngine.Context;

		scene.Physics2DSettings.Gravity = gravity;
	}

#endregion Physics2D

#region CircleRenderer
	
	[RegisterCall("ScriptGlue::CircleRenderer_GetColor")]
	static void CircleRenderer_GetColor(UUID entityId, out ColorRGBA color)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		color = circleRenderer.Color;
	}

	[RegisterCall("ScriptGlue::CircleRenderer_SetColor")]
	static void CircleRenderer_SetColor(UUID entityId, ColorRGBA color)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		circleRenderer.Color = color;
	}
	
	[RegisterCall("ScriptGlue::CircleRenderer_GetUvTransform")]
	static void CircleRenderer_GetUvTransform(UUID entityId, out float4 uvTransform)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		uvTransform = circleRenderer.UvTransform;
	}

	[RegisterCall("ScriptGlue::CircleRenderer_SetUvTransform")]
	static void CircleRenderer_SetUvTransform(UUID entityId, float4 uvTransform)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		circleRenderer.UvTransform = uvTransform;
	}
	
	[RegisterCall("ScriptGlue::CircleRenderer_GetInnerRadius")]
	static void CircleRenderer_GetInnerRadius(UUID entityId, out float innerRadius)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		innerRadius = circleRenderer.InnerRadius;
	}

	[RegisterCall("ScriptGlue::CircleRenderer_GetInnerRadius")]
	static void CircleRenderer_GetInnerRadius(UUID entityId, float innerRadius)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		circleRenderer.InnerRadius = innerRadius;
	}

#endregion

#region TextRenderer

	[RegisterCall("ScriptGlue::TextRenderer_SetIsRichText")]
	static bool TextRenderer_SetIsRichText(UUID entityId)
	{
		return GetComponentSafe<TextRendererComponent>(entityId).IsRichText;
	}

	[RegisterCall("ScriptGlue::TextRenderer_SetIsRichText")]
	static void TextRenderer_SetIsRichText(UUID entityId, bool isRichText)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);

		textComponent.IsRichText = isRichText;
		textComponent.NeedsRebuild = true;
	}

	[RegisterCall("ScriptGlue::TextRenderer_GetText")]
	static void TextRenderer_GetText(UUID entityId, out MonoString* text)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);

		text = Mono.mono_string_new_len(ScriptEngine.[Friend]s_AppDomain, textComponent.Text.Ptr, (uint32)textComponent.Text.Length);
	}

	[RegisterCall("ScriptGlue::TextRenderer_SetText")]
	static void TextRenderer_SetText(UUID entityId, MonoString* text)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);

		char8* rawText = Mono.mono_string_to_utf8(text);

		textComponent.Text = StringView(rawText);

		textComponent.NeedsRebuild = true;

		Mono.mono_free(rawText);
	}

	[RegisterCall("ScriptGlue::TextRenderer_GetColor")]
	static void TextRenderer_GetColor(UUID entityId, out ColorRGBA color)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		color = textComponent.Color;
	}

	[RegisterCall("ScriptGlue::TextRenderer_SetColor")]
	static void TextRenderer_SetColor(UUID entityId, ColorRGBA color)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		textComponent.Color = color;
		textComponent.NeedsRebuild = true;
	}

	[RegisterCall("ScriptGlue::TextRenderer_GetHorizontalAlignment")]
	static void TextRenderer_GetHorizontalAlignment(UUID entityId, out HorizontalTextAlignment horizontalAlignment)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		horizontalAlignment = textComponent.HorizontalAlignment;
	}

	[RegisterCall("ScriptGlue::TextRenderer_SetHorizontalAlignment")]
	static void TextRenderer_SetHorizontalAlignment(UUID entityId, HorizontalTextAlignment horizontalAlignment)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		textComponent.HorizontalAlignment = horizontalAlignment;
		textComponent.NeedsRebuild = true;
	}
	
	[RegisterCall("ScriptGlue::TextRenderer_GetFontSize")]
	static void TextRenderer_GetFontSize(UUID entityId, out float fontSize)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		fontSize = textComponent.FontSize;
	}

	[RegisterCall("ScriptGlue::TextRenderer_SetFontSize")]
	static void TextRenderer_SetFontSize(UUID entityId, float fontSize)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		textComponent.FontSize = fontSize;
		textComponent.NeedsRebuild = true;
	}

#endregion

#region Math

	private static void RegisterMathFunctions()
	{
		RegisterCall<function float(float, out float)>("ScriptGlue::modf_float", => GlitchyEngine.Math.modf);
		RegisterCall<function float2(float2, out float2)>("ScriptGlue::modf_float2", => GlitchyEngine.Math.modf);
		RegisterCall<function float3(float3, out float3)>("ScriptGlue::modf_float3", => GlitchyEngine.Math.modf);
		RegisterCall<function float4(float4, out float4)>("ScriptGlue::modf_float4", => GlitchyEngine.Math.modf);
		
		RegisterHalfFunctions();
	}

	private static void RegisterHalfFunctions()
	{
		RegisterCall<function void(float, out half)>("Math.Half::FromFloat32", (value, halfValue) => halfValue = GlitchyEngine.Math.half.FromFloat32(value));
		RegisterCall<function void(half, out float)>("Math.Half::ToFloat32", (value, floatValue) => floatValue = GlitchyEngine.Math.half.ToFloat32(value));
		
		RegisterCall<function void(half, half, out bool)>("Math.Half::LessThan_Impl", (left, right, result) => result = left < right);
		RegisterCall<function void(half, half, out bool)>("Math.Half::LessThanOrEqual_Impl", (left, right, result) => result = left <= right);
		RegisterCall<function void(half, half, out bool)>("Math.Half::GreaterThan_Impl", (left, right, result) => result = left > right);
		RegisterCall<function void(half, half, out bool)>("Math.Half::GreaterThanOrEqual_Impl", (left, right, result) => result = left >= right);

		RegisterCall<function void(half, half, out half)>("Math.Half::Add_Impl", (left, right, result) => result = left + right);
		RegisterCall<function void(half, half, out half)>("Math.Half::Subtract_Impl", (left, right, result) => result = left - right);
		RegisterCall<function void(half, half, out half)>("Math.Half::Multiply_Impl", (left, right, result) => result = left * right);
		RegisterCall<function void(half, half, out half)>("Math.Half::Divide_Impl", (left, right, result) => result = left / right);
		RegisterCall<function void(half, half, out half)>("Math.Half::Modulo_Impl", (left, right, result) => result = left % right);
		RegisterCall<function void(half, out half)>("Math.Half::Negate_Impl", (value, result) => result = -value);
		RegisterCall<function void(half, out half)>("Math.Half::Increment_Impl", (value, result) => result = ++value);
		RegisterCall<function void(half, out half)>("Math.Half::Decrement_Impl", (value, result) => result = --value);
		
		RegisterCall<function bool(half)>("Math.Half::IsNegative_Impl", (value) => value.IsNegative);
		RegisterCall<function bool(half)>("Math.Half::IsFinite_Impl", (value) => value.IsFinite);
		RegisterCall<function bool(half)>("Math.Half::IsInfinity_Impl", (value) => value.IsInfinity);
		RegisterCall<function bool(half)>("Math.Half::IsNan_Impl", (value) => value.IsNaN);
		RegisterCall<function bool(half)>("Math.Half::IsSubnormal_Impl", (value) => value.IsSubnormal);
	}

#endregion

	[RegisterCall("ScriptGlue::UUID_CreateNew")]
	static void UUID_Create(out UUID id)
	{
		id = UUID.Create();
	}

#region Application
	
	[RegisterCall("ScriptGlue::Application_IsEditor")]
	static bool Application_IsEditor()
	{
		return ScriptEngine.ApplicationInfo.IsEditor;
	}

	[RegisterCall("ScriptGlue::Application_IsPlayer")]
	static bool Application_IsPlayer()
	{
		return ScriptEngine.ApplicationInfo.IsPlayer;
	}

	[RegisterCall("ScriptGlue::Application_IsInEditMode")]
	static bool Application_IsInEditMode()
	{
		return ScriptEngine.ApplicationInfo.IsInEditMode;
	}

	[RegisterCall("ScriptGlue::Application_IsInPlayMode")]
	static bool Application_IsInPlayMode()
	{
		return ScriptEngine.ApplicationInfo.IsInPlayMode;
	}

#endregion

#region Serialization

	[RegisterCall("ScriptGlue::Serialization_SerializeField")]
	static void Serialization_SerializeField(void* serializationContext, SerializationType type, MonoString* nameObject, MonoObject* valueObject, MonoString* fullTypeName)
	{
		SerializedObject context = Internal.UnsafeCastToObject(serializationContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);

		char8* name = Mono.mono_string_to_utf8(nameObject);

		context.AddField(StringView(name), type, valueObject, fullTypeName);
		
		Mono.mono_free(name);
	}
	
	[RegisterCall("ScriptGlue::Serialization_CreateObject")]
	static void Serialization_CreateObject(void* currentContext, bool isStatic, MonoString* typeName, out void* newContext, out UUID newId)
	{
		SerializedObject context = Internal.UnsafeCastToObject(currentContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);
		
		char8* rawTypeName = Mono.mono_string_to_utf8(typeName);
		
		SerializedObject newObject = new SerializedObject(context.Serializer, isStatic, StringView(rawTypeName));

		Mono.mono_free(rawTypeName);

		newContext = Internal.UnsafeCastToPtr(newObject);
		newId = newObject.Id;
	}
	
	[RegisterCall("ScriptGlue::Serialization_DeserializeField")]
	public static void Serialization_DeserializeField(void* internalContext, SerializationType expectedType, MonoString* fieldName, uint8* target, out SerializationType actualType)
	{
		SerializedObject context = Internal.UnsafeCastToObject(internalContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);
		
		char8* name = Mono.mono_string_to_utf8(fieldName);

		context.GetField(StringView(name), expectedType, target, out actualType);

		Mono.mono_free(name);
	}
	
	[RegisterCall("ScriptGlue::Serialization_GetObject")]
	public static void Serialization_GetObject(void* internalContext, UUID id, out void* objectContext)
	{
		SerializedObject context = Internal.UnsafeCastToObject(internalContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);
		
		objectContext = null;

		Log.EngineLogger.AssertDebug(context.Serializer.ContainsId(context.Id));

		if (!context.Serializer.TryGetSerializedObject(id, let foundObject))
			return;

		objectContext = Internal.UnsafeCastToPtr(foundObject);
	}
	
	[RegisterCall("ScriptGlue::Serialization_GetObjectTypeName")]
	public static void Serialization_GetObjectTypeName(void* internalContext, out MonoString* fullTypeName)
	{
		SerializedObject context = Internal.UnsafeCastToObject(internalContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);

		fullTypeName = Mono.mono_string_new(ScriptEngine.[Friend]s_AppDomain, context.TypeName);
	}

#endregion

#region ImGui Extension
	
	[RegisterCall("ScriptGlue::ImGuiExtension_ListElementGrabber")]
	static void ImGuiExtension_ListElementGrabber()
	{
		ImGui.ImGui.ListElementGrabber();
	}

#endregion

	private static void RegisterCall<T>(String name, T method) where T : var
	{
		Mono.mono_add_internal_call(scope $"GlitchyEngine.{name}", (void*)method);
	}
}
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

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;

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
	}

	[RegisterMethod]
	private static void RegisterCalls()
	{
		// Generated at CompTime
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

	[RegisterCall("Log::LogMessage_Impl")]
	static void Log(int32 logLevel, MonoString* message)
	{
		char8* utfMessage = Mono.mono_string_to_utf8(message);

		Log.ClientLogger.Log((LogLevel)logLevel, StringView(utfMessage));

		Mono.mono_free(utfMessage);
	}

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
		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);
		ScriptEngine.Context.DestroyEntityDeferred(entity);
	}

	[RegisterCall("ScriptGlue::Entity_CreateInstance")]
	static void Entity_CreateInstance(UUID entityId, out UUID newEntityId)
	{
		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);
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
			Entity_AddComponent(entityId, reflectionType);
		}
	}

	[RegisterCall("ScriptGlue::Entity_AddComponent")]
	static void Entity_AddComponent(UUID entityId, MonoReflectionType* componentType)
	{
		MonoType* type = Mono.mono_reflection_type_get_type(componentType);

		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);
		if (s_AddComponentMethods.TryGetValue(type, let addMethod))
			addMethod(entity);
		else
			Log.EngineLogger.AssertDebug(false, "No managed component with the given type registered.");
	}
	
	[RegisterCall("ScriptGlue::Entity_HasComponent")]
	static bool Entity_HasComponent(UUID entityId, MonoReflectionType* componentType)
	{
		MonoType* type = Mono.mono_reflection_type_get_type(componentType);

		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);
		if (s_HasComponentMethods.TryGetValue(type, let hasMethod))
			return hasMethod(entity);

		Log.EngineLogger.AssertDebug(false, "No managed component with the given type registered.");

		return false;
	}
	
	[RegisterCall("ScriptGlue::Entity_RemoveComponent")]
	static void Entity_RemoveComponent(UUID entityId, MonoReflectionType* componentType)
	{
		MonoType* type = Mono.mono_reflection_type_get_type(componentType);

		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);
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
		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);

		if (!entity.HasComponent<ScriptComponent>())
		{
			entity.AddComponent<ScriptComponent>();
		}

		if (entity.TryGetComponent<ScriptComponent>(let scriptComponent))
		{
			scriptComponent.Instance = null;

			MonoType* type = Mono.mono_reflection_type_get_type(scriptType);

			scriptComponent.ScriptClassName = StringView(Mono.mono_type_full_name(type));
			
			// Initializes the created instance
			// TODO: this returns false, if no script with ScriptClassName exists, we have to handle this case correctly I think.
			ScriptEngine.InitializeInstance(entity, scriptComponent);

			return scriptComponent.Instance.MonoInstance;
		}

		return null;
	}
	
	[RegisterCall("ScriptGlue::Entity_RemoveScript")]
	static void Entity_RemoveScript(UUID entityId)
	{
		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);

		if (entity.TryGetComponent<ScriptComponent>(let scriptComponent))
		{
			ScriptEngine.DestroyInstance(entity, scriptComponent);
			
			entity.RemoveComponent<ScriptComponent>();
		}
	}
	
	[RegisterCall("ScriptGlue::Entity_GetName")]
    static MonoString* Entity_GetName(UUID entityId)
	{
		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);

		MonoString* name = Mono.mono_string_new_len(ScriptEngine.[Friend]s_AppDomain, entity.Name.Ptr, (.)entity.Name.Length);

		return name;
	}
    
	[RegisterCall("ScriptGlue::Entity_SetName")]
    static void Entity_SetName(UUID entityId, MonoString* name)
	{		
		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);

		char8* rawName = Mono.mono_string_to_utf8(name);

		entity.Name = StringView(rawName);

		Mono.mono_free(rawName);
	}

#endregion

#region TransformComponent
	
	[RegisterCall("ScriptGlue::Transform_GetTranslation")]
	static void Transform_GetTranslation(UUID entityId, out float3 translation)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		translation = entity.Transform.Position;
	}

	[RegisterCall("ScriptGlue::Transform_SetTranslation")]
	static void Transform_SetTranslation(UUID entityId, in float3 translation)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		entity.Transform.Position = translation;

		// if necessary reposition Rigidbody2D
		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetPosition(translation.XY);
		}
	}

#endregion TransformComponent

#region Rigidbody2D
	
	[RegisterCall("ScriptGlue::Rigidbody2D_ApplyForce")]
	static void Rigidbody2D_ApplyForce(UUID entityId, in float2 force, in float2 point, bool wakeUp)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		Box2D.Body.ApplyForce(rigidBody.[Friend]RuntimeBody, force, point, wakeUp);
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_ApplyForceToCenter")]
	static void Rigidbody2D_ApplyForceToCenter(UUID entityId, in float2 force, bool wakeUp)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		Box2D.Body.ApplyForceToCenter(rigidBody.[Friend]RuntimeBody, force, wakeUp);
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_SetPosition")]
	static void Rigidbody2D_SetPosition(UUID entityId, in float2 position)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		rigidBody.SetPosition(position);
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_GetPosition")]
	static void Rigidbody2D_GetPosition(UUID entityId, out float2 position)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		position = rigidBody.GetPosition();
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_SetRotation")]
	static void Rigidbody2D_SetRotation(UUID entityId, in float rotation)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		rigidBody.SetAngle(rotation);
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_GetRotation")]
	static void Rigidbody2D_GetRotation(UUID entityId, out float rotation)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		rotation = rigidBody.GetAngle();
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_GetLinearVelocity")]
	static void Rigidbody2D_GetLinearVelocity(UUID entityId, out float2 velocity)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		velocity = rigidBody.GetLinearVelocity();
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_SetLinearVelocity")]
	static void Rigidbody2D_SetLinearVelocity(UUID entityId, in float2 velocity)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);
		
		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		rigidBody.SetLinearVelocity(velocity);
	}

	[RegisterCall("ScriptGlue::Rigidbody2D_GetAngularVelocity")]
	static void Rigidbody2D_GetAngularVelocity(UUID entityId, out float velocity)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		velocity = rigidBody.GetAngularVelocity();
	}
	
	[RegisterCall("ScriptGlue::Rigidbody2D_SetAngularVelocity")]
	static void Rigidbody2D_SetAngularVelocity(UUID entityId, in float velocity)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);
		
		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		rigidBody.SetAngularVelocity(velocity);
	}

#endregion Rigidbody2D

#region Physics2D

	// TODO: We need a wrapper class!

	[RegisterCall("ScriptGlue::Physics2D_GetGravity")]
	static void Physics2D_GetGravity(out float2 gravity)
	{
		Scene scene = ScriptEngine.Context;

		var box2DGravity = Box2D.World.GetGravity(scene.[Friend]_physicsWorld2D);
		gravity = *(float2*)&box2DGravity;
	}

	[RegisterCall("ScriptGlue::Physics2D_SetGravity")]
	static void Physics2D_SetGravity(in float2 gravity)
	{
		Scene scene = ScriptEngine.Context;

#unwarn
		Box2D.World.SetGravity(scene.[Friend]_physicsWorld2D, gravity);
	}

#endregion Physics2D

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
	static void Serialization_CreateObject(void* currentContext, MonoString* typeName, out void* newContext, out UUID newId)
	{
		SerializedObject context = Internal.UnsafeCastToObject(currentContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);
		
		char8* rawTypeName = Mono.mono_string_to_utf8(typeName);
		
		SerializedObject newObject = new SerializedObject(context.AllObjects, StringView(rawTypeName));

		Mono.mono_free(rawTypeName);

		newContext = Internal.UnsafeCastToPtr(newObject);
		newId = newObject.Id;
	}
	
	[RegisterCall("ScriptGlue::Serialization_DeserializeField")]
	public static void Serialization_DeserializeField(void* internalContext, SerializationType expectedType, MonoString* fieldName, uint8* target)
	{
		SerializedObject context = Internal.UnsafeCastToObject(internalContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);
		
		char8* name = Mono.mono_string_to_utf8(fieldName);

		context.GetField(StringView(name), expectedType, target);

		Mono.mono_free(name);
	}
	
	[RegisterCall("ScriptGlue::Serialization_GetObject")]
	public static void Serialization_GetObject(void* internalContext, UUID id, out void* objectContext)
	{
		SerializedObject context = Internal.UnsafeCastToObject(internalContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);
		
		objectContext = null;

		if (!context.AllObjects.TryGetValue(id, let foundObject))
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

	private static void RegisterCall<T>(String name, T method) where T : var
	{
		Mono.mono_add_internal_call(scope $"GlitchyEngine.{name}", (void*)method);
	}
}
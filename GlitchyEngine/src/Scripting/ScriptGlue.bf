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
	}

	public static void RegisterManagedComponents()
	{
		RegisterComponent<TransformComponent>("GlitchyEngine.Transform");
		RegisterComponent<Rigidbody2DComponent>("GlitchyEngine.RigidBody2D");
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
			Log.EngineLogger.AssertDebug(managedType != null, scope $"No C# component with name \"{{className}}\" found for Beef type \"{typeof(T)}\"");
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
	static MonoObject* Entity_GetScriptInstance(UUID entityId)
	{
		return ScriptEngine.GetManagedInstance(entityId);
	}

#endregion

#region TransformComponent
	
	[RegisterCall("ScriptGlue::Transform_GetTranslation")]
	static void Transform_GetTranslation(UUID entityId, ref float3 translation)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		translation = entity.Transform.Position;
	}

	[RegisterCall("ScriptGlue::Transform_SetTranslation")]
	static void Transform_SetTranslation(UUID entityId, ref float3 translation)
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

#region RigidBody2D
	
	[RegisterCall("ScriptGlue::RigidBody2D_ApplyForce")]
	static void RigidBody2D_ApplyForce(UUID entityId, ref float2 force, ref float2 point, bool wakeUp)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		Box2D.Body.ApplyForce(rigidBody.[Friend]RuntimeBody, ref *(Box2D.b2Vec2*)&force, ref *(Box2D.b2Vec2*)&point, wakeUp);
	}
	
	[RegisterCall("ScriptGlue::RigidBody2D_ApplyForceToCenter")]
	static void RigidBody2D_ApplyForceToCenter(UUID entityId, ref float2 force, bool wakeUp)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		var rigidBody = entity.GetComponent<Rigidbody2DComponent>();
		Box2D.Body.ApplyForceToCenter(rigidBody.[Friend]RuntimeBody, ref *(Box2D.b2Vec2*)&force, wakeUp);
	}

#endregion RigidBody2D

#region Physics2D

	// TODO: We need a wrapper class!

	[RegisterCall("ScriptGlue::Physics2D_GetGravity")]
	static void Physics2D_GetGravity(ref float2 gravity)
	{
		Scene scene = ScriptEngine.Context;

		var box2DGravity = Box2D.World.GetGravity(scene.[Friend]_physicsWorld2D);
		gravity = *(float2*)&box2DGravity;
	}

	[RegisterCall("ScriptGlue::Physics2D_SetGravity")]
	static void Physics2D_SetGravity(ref float2 gravity)
	{
		Scene scene = ScriptEngine.Context;

#unwarn
		Box2D.World.SetGravity(scene.[Friend]_physicsWorld2D, ref *(b2Vec2*)&gravity);
	}

#endregion Physics2D

	private static void RegisterCall<T>(String name, T method) where T : var
	{
		Mono.mono_add_internal_call(scope $"GlitchyEngine.{name}", (void*)method);
	}
}
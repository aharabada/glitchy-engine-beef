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
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using System.Diagnostics;
using System.IO;
using System.Linq;
using static GlitchyEngine.Scripting.ScriptGlue;

using static GlitchyEngine.Renderer.Text.FontRenderer;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;
using internal GlitchyEngine.Content;

// TODO: Move to logger?
class MessageOrigin
{
	private String _fileName ~ delete:append _;
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

[AttributeUsage(.Method)]
struct RegisterCallAttribute : Attribute
{
	public bool EngineResultAsBool { get; set mut; }
	public bool IsExtension { get; set mut; }
}

struct TypeTranslationTemplate
{
	public String StartCode;
	public String EndCode;
	public String PrettyCSharpParamType;

	public this(String startCode, String endCode, String prettyCSharpParamType)
	{
		StartCode = startCode;
		EndCode = endCode;
		PrettyCSharpParamType = prettyCSharpParamType;
	}
}

[AttributeUsage(.Parameter)]
struct GlueParamAttribute : Attribute
{
	public String WrapperType;

	public this(String wrapperType)
	{
		WrapperType = wrapperType;
	}
}

[AttributeUsage(.Struct)]
struct EngineFunctionsGeneratorAttribute : Attribute, IComptimeTypeApply
{
	private static String GetTypeInfo(Type type, RegisterCallAttribute? callAttribute = null)
	{
		String value = new .();
		type.ToString(value);

		if (type.IsEnum)
		{
			// Pass the underlying integer type for enums.
			value.AppendF($" : {type.UnderlyingType}");
		}
		else if (!type.HasCustomAttribute<CReprAttribute>() && !type.IsPrimitive && !type.IsPointer && !(type is RefType))
		{
			// For CDecl Functions beef ecpects non CRepr struct to be passed as readonly ref.
			// Thus we add in to the type name. However primitive types are passed by value!
			value.Insert(0, "in ");
		}

		// EngineResult will usually just be converted to exceptions -> script method returns void
		// But sometimes we want to be able to also return a boolean value.
		if (type == typeof(EngineResult) && callAttribute.HasValue)
		{
			if (callAttribute.Value.EngineResultAsBool)
			{
				value.Append(" as bool");
			}
			else
			{
				value.Append(" as void");
			}
		}

		return value;
	}
	
	private static void GenerateJsonInfo(MethodInfo method, RegisterCallAttribute registerCallAttribute, String outString)
	{
		String parameters = new String();
		
		StringView str = method.Name;

		for (int i < method.ParamCount)
		{
			if (i != 0)
				parameters.Append(", ");

			parameters.AppendF($"""

							{{
								"name": "{method.GetParamName(i)}",
								"type": "{GetTypeInfo(method.GetParamType(i))}"
							}}
				""");
		}

		outString.AppendF($"""

				{{
					"name": "{method.Name}",
					"return_type": "{GetTypeInfo(method.ReturnType, registerCallAttribute)}",
					"parameters": [{parameters}
					]
				}},
			""");
	}

	[Comptime]
	public void ApplyToType(Type self)
    {
		String jsonOutput = new String("[");

        for (MethodInfo methodInfo in typeof(ScriptGlue).GetMethods(.Static | .NonPublic))
		{
			if (methodInfo.GetCustomAttribute<RegisterCallAttribute>() case .Ok(let attribute))
			{
				String parameters = new String();

				for (int i < methodInfo.ParamCount)
				{
					if (i != 0)
						parameters.Append(", ");

					parameters.AppendF($"{methodInfo.GetParamType(i)}");
				}

				String line = scope $"public function [CallingConvention(.Cdecl)] {methodInfo.ReturnType}({parameters}) {methodInfo.Name};\n";

				Compiler.EmitTypeBody(self, line);

				GenerateJsonInfo(methodInfo, attribute, jsonOutput);
			}
		}

		if (jsonOutput.EndsWith(","))
		{
			jsonOutput.RemoveFromEnd(1);
		}

		jsonOutput.Append(']');

		Directory.CreateDirectory("../generated");

		if (File.WriteAllText("../generated/ScriptGlue.json", jsonOutput) case .Err)
		{
			Runtime.FatalError("Failed to write file");
		}
    }
}

[EngineFunctionsGenerator]
struct EngineFunctions
{
	static Self _functions;
	
	[RegisterMethod]
	public static void FillEngineFunctions()
	{
		
		OnRegisterNativeCalls.Invoke();

		ScriptGlue.[Friend]_setEngineFunctions(&_functions);
	}
}

/* Adding this attribute to a method will log method entry and returned Result<T> errors */
[AttributeUsage(.Method)]
public struct RegisterMethodAttribute : Attribute, IOnMethodInit
{
    [Comptime]
    public void OnMethodInit(MethodInfo method, Self* prev)
    {
		String functionContent = new .();

		int i = 0;

        for (var methodInfo in typeof(ScriptGlue).GetMethods(.Static | .NonPublic | .FlattenHierarchy))
		{
			if (methodInfo.GetCustomAttribute<RegisterCallAttribute>() case .Ok(let attribute) && !attribute.IsExtension)
			{
				functionContent.AppendF($"_functions.{methodInfo.Name} = => ScriptGlue.[Friend]{methodInfo.Name};\n");
				//functionContent.AppendF($"functions[{i}] = (void*)( => {methodInfo.Name});\n");
				i++;
			}
		}

		//functionContent.Insert(0, scope $"EngineFunctions functions = .();\n");

		Compiler.EmitMethodEntry(method, functionContent);
    }
}

static class ScriptGlue
{
	public static Event<delegate void()> OnRegisterNativeCalls ~ _.Dispose();

	private function void SetEngineFunctions(EngineFunctions* engineFunctions);
	private static SetEngineFunctions _setEngineFunctions;

	private static String _lastExceptionMessage = new .() ~ delete _;

	public static void Init()
	{
		if (_setEngineFunctions == null)
		{
			CoreClrHelper.GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "SetEngineFunctions", out _setEngineFunctions);
		}

		RegisterCalls();

		RegisterManagedComponents();
	}

	public static void RegisterManagedComponents()
	{
		Debug.Profiler.ProfileFunction!();

		RegisterComponent<TransformComponent>();
		RegisterComponent<Rigidbody2DComponent>();
		RegisterComponent<CameraComponent>();
		RegisterComponent<SpriteRendererComponent>();
		RegisterComponent<CircleRendererComponent>();
		RegisterComponent<TextRendererComponent>();
		RegisterComponent<MeshComponent>();
		RegisterComponent<MeshRendererComponent>();
	}

	private static void RegisterCalls()
	{
		EngineFunctions.FillEngineFunctions();
	}
	
	private static void RegisterComponent<T>() where T : struct, new
	{
		String fullComponentTypeName = scope String();
		typeof(T).GetFullName(fullComponentTypeName);

		CoreClrHelper.RegisterComponent(fullComponentTypeName..EnsureNullTerminator(),
			addComponent: (entityId) =>
			{
				if (GetEntitySafe(entityId) case .Ok(Entity entity))
				{
					entity.AddComponent<T>();
					return .Ok;
				}
				
				return .EntityNotFound;
			},
			hasComponent: (entityId) =>
			{
				if (GetEntitySafe(entityId) case .Ok(Entity entity))
				{
					return entity.HasComponent<T>() ? .Ok : .False;
				}
				
				return .EntityNotFound;
			},
			removeComponent: (entityId) =>
			{
				if (GetEntitySafe(entityId) case .Ok(Entity entity))
				{
					entity.RemoveComponent<T>();
					return .Ok;
				}
				
				return .EntityNotFound;
			});
	}

	/// Gets the entity with the given id. Throws a mono exception, if the entity doesn't exist.
	static Result<Entity> GetEntitySafe(UUID entityId)
	{
		if (ScriptEngine.Context.GetEntityByID(entityId) case .Ok(let entity))
		{
			return entity;
		}

		return .Err;
	}

	static mixin GetEntityOrReturnError(UUID entityId)
	{
		if (GetEntitySafe(entityId) not case .Ok(let entity))
		{
			return EngineResult.EntityNotFound;
		}

		entity
	}

	/// Gets the component of the specified type that is attached to the given entity. Or null, if the entity doesn't exist or doesn't have the specified component.
	static Result<T*, EngineResult> GetComponentSafe<T>(UUID entityId) where T: struct, new
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
				return .Err(.EntityDoesntHaveComponent);
			}
		}
		else
		{
			return .Err(.EntityNotFound);
		}
	}

	static mixin GetComponentOrReturn<T>(UUID entityId) where T: struct, new
	{
		Result<T*, EngineResult> result = GetComponentSafe<T>(entityId);
		if (result case .Err(EngineResult error))
		{
			return error;
		}

		result.Value
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

	public enum EngineResult : int32
	{
		case Ok = 0; // Success, for boolean return value means True
		case False = 1; // Success, for boolean return value means False
		case Error = -1;
		case NotImplemented = -2;
		case ArgumentError = -3;

		// Entity Errors:
		case EntityNotFound = -4; // The entity doesn't exist or was deleted.
		case EntityDoesntHaveComponent = -5; // The entity has no component of type {typeof(T)} or it was deleted.
		case AssetNotFound = -6; // No asset exists for AssetHandle \"{assetId}\".

		case CustomError = 1 << 31;

		public static EngineResult CustomError(int32 payload)
		{
			return CustomError | payload;
		}
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static StringView GetLastExceptionMessage()
	{
		return _lastExceptionMessage;
	}

#region Log

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Log_LogMessage(LogLevel logLevel, StringView messagePtr, StringView fileNamePtr, int lineNumber)
	{
		String escapedMessage = new:ScopedAlloc! String(messagePtr);

		// Escape the message, because the editor logger does a string-format
		escapedMessage.Replace("{", "{{");
		escapedMessage.Replace("}", "}}");

		if (!fileNamePtr.IsEmpty)
		{
			String fileName = new:ScopedAlloc! String(fileNamePtr);

			MessageOrigin messageOrigin = scope MessageOrigin(fileName, lineNumber);

			Log.ClientLogger.Log((LogLevel)logLevel, escapedMessage, messageOrigin);
		}
		else
		{
			Log.ClientLogger.Log((LogLevel)logLevel, escapedMessage);
		}
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Log_LogException(UUID entityId, StringView fullExceptionClassName, StringView exceptionMessage, StringView stackTrace)
	{
		ScriptException exception = new ScriptException(entityId, fullExceptionClassName, exceptionMessage, stackTrace);
		ScriptEngine.LogScriptException(exception, entityId);
	}

#endregion

#region Input

	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Input_IsKeyPressed(Key key) => Input.IsKeyPressed(key);

	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Input_IsKeyReleased(Key key) => Input.IsKeyReleased(key);
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Input_IsKeyToggled(Key key) => Input.IsKeyToggled(key);

	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Input_IsKeyPressing(Key key) => Input.IsKeyPressing(key);

	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Input_IsKeyReleasing(Key key) => Input.IsKeyReleasing(key);

	
	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Input_IsMouseButtonPressed(MouseButton mouseButton) => Input.IsMouseButtonPressed(mouseButton);

	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Input_IsMouseButtonReleased(MouseButton mouseButton) => Input.IsMouseButtonReleased(mouseButton);

	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Input_IsMouseButtonPressing(MouseButton mouseButton) => Input.IsMouseButtonPressing(mouseButton);

	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Input_IsMouseButtonReleasing(MouseButton mouseButton) => Input.IsMouseButtonReleasing(mouseButton);

#endregion Input

#region Scene/Entity stuff

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Entity_Create(StringView entityName, out UUID entityId)
	{
		Entity entity = ScriptEngine.Context.CreateEntity(entityName);

		entityId = entity.UUID;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Entity_Destroy(UUID entityId)
	{
		Entity entity = GetEntityOrReturnError!(entityId);
		ScriptEngine.Context.DestroyEntityDeferred(entity);
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Entity_CreateInstance(UUID entityId, out UUID newEntityId)
	{
		newEntityId = ?;
		Entity entity = GetEntityOrReturnError!(entityId);
		Entity newEntity = ScriptEngine.Context.CreateInstance(entity);

		newEntityId = newEntity.UUID;
		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Entity_FindEntityWithName(StringView entityName, out UUID outUuid)
	{
		outUuid = UUID(0);

		Result<Entity> entityResult = ScriptEngine.Context.GetEntityByName(entityName);

		if (entityResult case .Ok(let entity))
			outUuid = entity.UUID;
	}

	// TODO: Do we need this?
	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Entity_GetScriptInstance(UUID entityId, out void* instance)
	{
		instance = ?;
 		return .NotImplemented;
		//instance = ScriptEngine.GetManagedInstance(entityId);
	}

	[RegisterCall(EngineResultAsBool = true), CallingConvention(.Cdecl)]
	static EngineResult Entity_SetScript(UUID entityId, StringView fullScriptTypeName)
	{
		Entity entity = GetEntityOrReturnError!(entityId);

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

		scriptComponent.ScriptClassName = fullScriptTypeName;
		
		// Initializes the created instance
		// TODO: this returns false, if no script with ScriptClassName exists, we have to handle this case correctly I think.
		if (!ScriptEngine.InitializeInstance(entity, scriptComponent))
		{
			return .ArgumentError;
		}

		//return scriptComponent.Instance.MonoInstance;
		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Entity_RemoveScript(UUID entityId)
	{
		ScriptComponent* scriptComponent = GetComponentOrReturn!<ScriptComponent>(entityId);

		ScriptEngine.Context.DestroyScriptDeferred(scriptComponent.Instance, true);

		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
    static StringView Entity_GetName(UUID entityId)
	{
		Result<Entity> foundEntity = ScriptEngine.Context.GetEntityByID(entityId);

		if (foundEntity case .Ok(let entity))
		{
			return entity.Name;
		}

		return null;
	}
    
	[RegisterCall, CallingConvention(.Cdecl)]
    static EngineResult Entity_SetName(UUID entityId, StringView name)
	{
		GetEntityOrReturnError!(entityId).Name = name;
		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
    static void Entity_GetEditorFlags(UUID entityId, out EditorFlags editorFlags)
	{
		editorFlags = .Default;
#if GE_EDITOR
		if (TryGetEntitySafe(entityId, let entity))
			editorFlags = entity.EditorFlags;
#endif
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
    static void Entity_SetEditorFlags(UUID entityId, EditorFlags editorFlags)
	{
#if GE_EDITOR
		if (TryGetEntitySafe(entityId, let entity))
			entity.EditorFlags = editorFlags;
#endif
	}

#endregion

#region TransformComponen

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_GetParent(UUID entityId, out UUID parentId)
	{
		parentId = .Zero;
		Entity entity = GetEntityOrReturnError!(entityId);

		parentId = entity.Parent?.UUID ?? .Zero;

		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_SetParent(UUID entityId, UUID newParentId)
	{
		Entity entity = GetEntityOrReturnError!(entityId);

		Entity? newParent = null;
		if (newParentId != .Zero)
		{
			GetEntityOrReturnError!(newParentId);
		}

		entity.Parent = newParent;

		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_GetTranslation(UUID entityId, out float3 translation)
	{
		translation = ?;
		Entity entity = GetEntityOrReturnError!(entityId);
		translation = entity.Transform.Position;

		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_SetTranslation(UUID entityId, in float3 translation)
	{
		Entity entity = GetEntityOrReturnError!(entityId);
		entity.Transform.Position = translation;

		// if necessary reposition Rigidbody2D
		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetPosition(translation.XY);
		}
		// TODO: we need to handle repositioning of colliders that are children of the entity with rigidbody...
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_GetWorldTranslation(UUID entityId, out float3 translationWorld)
	{
		translationWorld = ?;
		Entity entity = GetEntityOrReturnError!(entityId);

		TransformComponent* transform = entity.Transform;

		translationWorld = transform.WorldTransform.Translation; //(float4(entity.Transform.Position, 1.0f) * entity.Transform.WorldTransform).XYZ;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_SetWorldTranslation(UUID entityId, in float3 translation)
	{
		Log.ClientLogger.Warning("Transform_SetWorldTranslation is not implemented!");
		return .NotImplemented;

		// Entity entity = GetEntitySafe(entityId);

		// entity.Transform.Position = translation;

		// // if necessary reposition Rigidbody2D
		// if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		// {
		// 	rigidbody2D.SetPosition(translation.XY);
		// }
		// TODO: we need to handle repositioning of colliders that are children of the entity with rigidbody...
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_TransformPointToWorld(UUID entityId, float3 point, out float3 pointWorld)
	{
		pointWorld = ?;
		Entity entity = GetEntityOrReturnError!(entityId);

		float3 localPoint = entity.Transform.Position;

		pointWorld = (float4(localPoint, 1.0f) * entity.Transform.WorldTransform).XYZ;
		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_GetRotation(UUID entityId, out Quaternion rotation)
	{
		rotation = ?;
		Entity entity = GetEntityOrReturnError!(entityId);

		rotation = entity.Transform.Rotation;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_SetRotation(UUID entityId, in Quaternion rotation)
	{
		Entity entity = GetEntityOrReturnError!(entityId);
		
		entity.Transform.Rotation = rotation;

		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetAngle(entity.Transform.RotationEuler.Z);
		}
		// TODO: When rotating around the X- or Y-axis we need to deform and reposition the colliders accordingly...
		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_GetRotationEuler(UUID entityId, out float3 rotationEuler)
	{
		rotationEuler = ?;
		Entity entity = GetEntityOrReturnError!(entityId);
		
		rotationEuler = entity.Transform.RotationEuler;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_SetRotationEuler(UUID entityId, in float3 rotationEuler)
	{
		Entity entity = GetEntityOrReturnError!(entityId);
		
		entity.Transform.RotationEuler = rotationEuler;

		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetAngle(rotationEuler.Z);
		}
		return .Ok;
	}

	[Packed]
	public struct AxisAngle
	{
		public float3 Axis;
		public float Angle;

		public this((float3 Axis, float Angle) axisAngle)
		{
			Axis = axisAngle.Axis;
			Angle = axisAngle.Angle;
		}
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_GetRotationAxisAngle(UUID entityId, out AxisAngle rotationAxisAngle)
	{
		rotationAxisAngle = ?;
		Entity entity = GetEntityOrReturnError!(entityId);
		
		rotationAxisAngle = AxisAngle(entity.Transform.RotationAxisAngle);
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_SetRotationAxisAngle(UUID entityId, AxisAngle rotationAxisAngle)
	{
		Entity entity = GetEntityOrReturnError!(entityId);
		
		entity.Transform.RotationAxisAngle = (rotationAxisAngle.Axis, rotationAxisAngle.Angle);

		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetAngle(entity.Transform.RotationEuler.Z);
		}
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_GetScale(UUID entityId, out float3 scale)
	{
		scale = ?;
		Entity entity = GetEntityOrReturnError!(entityId);
		
		scale = entity.Transform.Scale;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Transform_SetScale(UUID entityId, float3 scale)
	{
		Entity entity = GetEntityOrReturnError!(entityId);
		
		entity.Transform.Scale = scale;

		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			// TODO: we need to scale and reposition the colliders, this is a mess...
		}
		return .Ok;
	}

#endregion TransformComponent

#region Rigidbody2
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_ApplyForce(UUID entityId, in float2 force, in float2 point, bool wakeUp)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		Box2D.Body.ApplyForce(rigidBody.[Friend]RuntimeBody, force, point, wakeUp);
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_ApplyForceToCenter(UUID entityId, in float2 force, bool wakeUp)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		Box2D.Body.ApplyForceToCenter(rigidBody.[Friend]RuntimeBody, force, wakeUp);
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_SetPosition(UUID entityId, in float2 position)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetPosition(position);
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_GetPosition(UUID entityId, out float2 position)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		position = rigidBody.GetPosition();
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_SetRotation(UUID entityId, float rotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetAngle(rotation);
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_GetRotation(UUID entityId, out float rotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rotation = rigidBody.GetAngle();
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_GetLinearVelocity(UUID entityId, out float2 velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		velocity = rigidBody.GetLinearVelocity();
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_SetLinearVelocity(UUID entityId, in float2 velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetLinearVelocity(velocity);
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_GetAngularVelocity(UUID entityId, out float velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		velocity = rigidBody.GetAngularVelocity();
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_SetAngularVelocity(UUID entityId, float velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetAngularVelocity(velocity);
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_GetBodyType(UUID entityId, out Rigidbody2DComponent.BodyType bodyType)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		bodyType = rigidBody.BodyType;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_SetBodyType(UUID entityId, Rigidbody2DComponent.BodyType bodyType)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.BodyType = bodyType;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_IsFixedRotation(UUID entityId, out bool isFixedRotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		isFixedRotation = rigidBody.FixedRotation;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_SetFixedRotation(UUID entityId, bool isFixedRotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.FixedRotation = isFixedRotation;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_GetGravityScale(UUID entityId, out float gravityScale)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		gravityScale = rigidBody.GravityScale;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Rigidbody2D_SetGravityScale(UUID entityId, float gravityScale)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.GravityScale = gravityScale;
	}

#endregion Rigidbody2D

#region Camer

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_GetProjectionType(UUID entityId, out SceneCamera.ProjectionType projectionType)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		projectionType = camera.Camera.ProjectionType;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_SetProjectionType(UUID entityId, SceneCamera.ProjectionType projectionType)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.ProjectionType = projectionType;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_GetPerspectiveFovY(UUID entityId, out float fovY)
	{
	    CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		fovY = camera.Camera.PerspectiveFovY;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_SetPerspectiveFovY(UUID entityId, float fovY)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.PerspectiveFovY = fovY;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_GetPerspectiveNearPlane(UUID entityId, out float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		nearPlane = camera.Camera.PerspectiveNearPlane;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_SetPerspectiveNearPlane(UUID entityId, float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.PerspectiveNearPlane = nearPlane;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_GetPerspectiveFarPlane(UUID entityId, out float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		farPlane = camera.Camera.PerspectiveFarPlane;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_SetPerspectiveFarPlane(UUID entityId, float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.PerspectiveFarPlane = farPlane;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_GetOrthographicHeight(UUID entityId, out float height)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		height = camera.Camera.OrthographicHeight;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_SetOrthographicHeight(UUID entityId, float height)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.OrthographicHeight = height;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_SetOrthographicNearPlane(UUID entityId, float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.OrthographicNearPlane = nearPlane;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_GetOrthographicNearPlane(UUID entityId, out float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		nearPlane = camera.Camera.OrthographicNearPlane;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_SetOrthographicFarPlane(UUID entityId, float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.OrthographicFarPlane = farPlane;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_GetOrthographicFarPlane(UUID entityId, out float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		farPlane = camera.Camera.OrthographicFarPlane;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_SetAspectRatio(UUID entityId, float aspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.AspectRatio = aspectRatio;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_GetAspectRatio(UUID entityId, out float aspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		aspectRatio = camera.Camera.AspectRatio;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_SetFixedAspectRatio(UUID entityId, bool fixedAspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.FixedAspectRatio = fixedAspectRatio;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Camera_GetFixedAspectRatio(UUID entityId, out bool fixedAspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		fixedAspectRatio = camera.Camera.FixedAspectRatio;
	}

#endregion

#region Physics2D

	// TODO: We need a wrapper class!

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Physics2D_GetGravity(out float2 gravity)
	{
		Scene scene = ScriptEngine.Context;

		gravity = scene.Physics2DSettings.Gravity;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Physics2D_SetGravity(in float2 gravity)
	{
		Scene scene = ScriptEngine.Context;

		scene.Physics2DSettings.Gravity = gravity;
	}

#endregion Physics2D

	// TODO: Do we even need the circle renderer?
#region CircleRenderer
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void CircleRenderer_GetColor(UUID entityId, out ColorRGBA color)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		color = circleRenderer.Color;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void CircleRenderer_SetColor(UUID entityId, ColorRGBA color)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		circleRenderer.Color = color;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void CircleRenderer_GetUvTransform(UUID entityId, out float4 uvTransform)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		uvTransform = circleRenderer.UvTransform;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void CircleRenderer_SetUvTransform(UUID entityId, float4 uvTransform)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		circleRenderer.UvTransform = uvTransform;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void CircleRenderer_GetInnerRadius(UUID entityId, out float innerRadius)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		innerRadius = circleRenderer.InnerRadius;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static void CircleRenderer_SetInnerRadius(UUID entityId, float innerRadius)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		circleRenderer.InnerRadius = innerRadius;
	}

#endregion

#region SpriteRenderer

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult SpriteRenderer_GetColor(UUID entityId, out ColorRGBA color)
	{
		color = ?;
		SpriteRendererComponent* spriteRenderer = GetComponentOrReturn!<SpriteRendererComponent>(entityId);
		color = spriteRenderer.Color;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult SpriteRenderer_SetColor(UUID entityId, ColorRGBA color)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentOrReturn!<SpriteRendererComponent>(entityId);
		spriteRenderer.Color = color;
		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult SpriteRenderer_GetUvTransform(UUID entityId, out float4 uvTransform)
	{
		uvTransform = ?;
		SpriteRendererComponent* spriteRenderer = GetComponentOrReturn!<SpriteRendererComponent>(entityId);
		uvTransform = spriteRenderer.UvTransform;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult SpriteRenderer_SetUvTransform(UUID entityId, float4 uvTransform)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentOrReturn!<SpriteRendererComponent>(entityId);
		spriteRenderer.UvTransform = uvTransform;
		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult SpriteRenderer_GetMaterial(UUID entityId, out AssetHandle assetId)
	{
		assetId = ?;
		SpriteRendererComponent* spriteRenderer = GetComponentOrReturn!<SpriteRendererComponent>(entityId);

		Material material = GetAssetOrReturn!<Material>((AssetHandle)spriteRenderer.Material);

		if (!material.IsRuntimeInstance)
		{
			using (material = new Material(material, true))
			{
				material.Identifier = scope $"(Instance) {material.Identifier}";
				//Content.ManageAsset(material);
				spriteRenderer.Material = material.Handle;
			}
		}

		assetId = spriteRenderer.Material;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult SpriteRenderer_SetMaterial(UUID entityId, AssetHandle assetId)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentOrReturn!<SpriteRendererComponent>(entityId);
		spriteRenderer.Material = assetId;
		return .Ok;
	}


#endregion

#region TextRenderer

	[RegisterCall(EngineResultAsBool = true), CallingConvention(.Cdecl)]
	static EngineResult TextRenderer_GetIsRichText(UUID entityId)
	{
		TextRendererComponent* textComponent = GetComponentOrReturn!<TextRendererComponent>(entityId);
		return textComponent.IsRichText ? .Ok : .False;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult TextRenderer_SetIsRichText(UUID entityId, bool isRichText)
	{
		TextRendererComponent* textComponent = GetComponentOrReturn!<TextRendererComponent>(entityId);

		textComponent.IsRichText = isRichText;
		textComponent.NeedsRebuild = true;

		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult TextRenderer_GetText(UUID entityId, out StringView text)
	{
		text = ?;
		TextRendererComponent* textComponent = GetComponentOrReturn!<TextRendererComponent>(entityId);

		text = textComponent.Text;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult TextRenderer_SetText(UUID entityId, StringView text)
	{
		TextRendererComponent* textComponent = GetComponentOrReturn!<TextRendererComponent>(entityId);

		textComponent.Text = text;

		textComponent.NeedsRebuild = true;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult TextRenderer_GetColor(UUID entityId, out ColorRGBA color)
	{
		color = ?;
		TextRendererComponent* textComponent = GetComponentOrReturn!<TextRendererComponent>(entityId);

		color = textComponent.Color;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult TextRenderer_SetColor(UUID entityId, ColorRGBA color)
	{
		TextRendererComponent* textComponent = GetComponentOrReturn!<TextRendererComponent>(entityId);

		textComponent.Color = color;
		textComponent.NeedsRebuild = true;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult TextRenderer_GetHorizontalAlignment(UUID entityId, [GlueParam("out HorizontalTextAlignment")] out HorizontalTextAlignment horizontalAlignment)
	{
		horizontalAlignment = ?;
		TextRendererComponent* textComponent = GetComponentOrReturn!<TextRendererComponent>(entityId);
		horizontalAlignment = textComponent.HorizontalAlignment;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult TextRenderer_SetHorizontalAlignment(UUID entityId, [GlueParam("HorizontalTextAlignment")] HorizontalTextAlignment horizontalAlignment)
	{
		TextRendererComponent* textComponent = GetComponentOrReturn!<TextRendererComponent>(entityId);
		textComponent.HorizontalAlignment = horizontalAlignment;
		textComponent.NeedsRebuild = true;
		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult TextRenderer_GetFontSize(UUID entityId, out float fontSize)
	{
		fontSize = ?;
		TextRendererComponent* textComponent = GetComponentOrReturn!<TextRendererComponent>(entityId);
		fontSize = textComponent.FontSize;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult TextRenderer_SetFontSize(UUID entityId, float fontSize)
	{
		TextRendererComponent* textComponent = GetComponentOrReturn!<TextRendererComponent>(entityId);
		textComponent.FontSize = fontSize;
		textComponent.NeedsRebuild = true;
		return .Ok;
	}

#endregion

#region Mesh
#endregion

#region MeshRenderer

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult MeshRenderer_GetMaterial(UUID entityId, out AssetHandle assetId)
	{
		assetId = ?;
		MeshRendererComponent* meshRenderer = GetComponentOrReturn!<MeshRendererComponent>(entityId);

		Material material = GetAssetOrReturn!<Material>((AssetHandle)meshRenderer.Material);
		
		if (!material.IsRuntimeInstance)
		{
			using (material = new Material(material, true))
			{
				material.Identifier = scope $"(Instance) {material.Identifier}";
				//Content.ManageAsset(material);
				meshRenderer.Material = material.Handle;
			}
		}

		assetId = meshRenderer.Material;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult MeshRenderer_GetSharedMaterial(UUID entityId, out AssetHandle assetId)
	{
		assetId = ?;
		MeshRendererComponent* meshRenderer = GetComponentOrReturn!<MeshRendererComponent>(entityId);

		Material material = GetAssetOrReturn!<Material>((AssetHandle)meshRenderer.Material);

		if (material.IsRuntimeInstance)
		{
			assetId = material.Parent.Handle;
		}
		else
		{
			assetId = meshRenderer.Material;
		}
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult MeshRenderer_SetMaterial(UUID entityId, AssetHandle assetId)
	{
		MeshRendererComponent* meshRenderer = GetComponentOrReturn!<MeshRendererComponent>(entityId);
		meshRenderer.Material = assetId;
		return .Ok;
	}

#endregion

#region Math
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static float Math_ModfFloat(float x, out float integerPart)
	{
		return modf(x, out integerPart);
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static float2 Math_ModfFloat2(float2 x, out float2 integerPart)
	{
		return modf(x, out integerPart);
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static float3 Math_ModfFloat3(float3 x, out float3 integerPart)
	{
		return modf(x, out integerPart);
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static float4 Math_ModfFloat4(float4 x, out float4 integerPart)
	{
		return modf(x, out integerPart);
	}

#endregion

	[RegisterCall, CallingConvention(.Cdecl)]
	static void UUID_Create(out UUID id)
	{
		id = UUID.Create();
	}

#region Application
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Application_IsEditor()
	{
		return ScriptEngine.ApplicationInfo.IsEditor;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Application_IsPlayer()
	{
		return ScriptEngine.ApplicationInfo.IsPlayer;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Application_IsInEditMode()
	{
		return ScriptEngine.ApplicationInfo.IsInEditMode;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static bool Application_IsInPlayMode()
	{
		return ScriptEngine.ApplicationInfo.IsInPlayMode;
	}

#endregion

#region Serialization

	[RegisterCall, CallingConvention(.Cdecl)]
	static void Serialization_SerializeField(void* serializationContext, SerializationType type, StringView fieldName, void* valueObject, StringView fullTypeName)
	{
		SerializedObject context = Internal.UnsafeCastToObject(serializationContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);

		context.AddField(fieldName, type, valueObject, fullTypeName);
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void Serialization_CreateObject(void* currentContext, bool isStatic, StringView typeName, out void* newContext, out UUID newId)
	{
		SerializedObject context = Internal.UnsafeCastToObject(currentContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);
		
		SerializedObject newObject = new SerializedObject(context.Serializer, isStatic, typeName);

		newContext = Internal.UnsafeCastToPtr(newObject);
		newId = newObject.Id;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	public static void Serialization_DeserializeField(void* internalContext, SerializationType expectedType, StringView fieldName, uint8* target, out SerializationType actualType)
	{
		SerializedObject context = Internal.UnsafeCastToObject(internalContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);
		
		context.GetField(fieldName, expectedType, target, out actualType);
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
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
	
	[RegisterCall, CallingConvention(.Cdecl)]
	public static void Serialization_GetObjectTypeName(void* internalContext, out StringView fullTypeName)
	{
		SerializedObject context = Internal.UnsafeCastToObject(internalContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);

		fullTypeName = context.TypeName;
	}

#endregion

#region Asset

	/*static mixin GetAssetOrThrow(UUID assetId)
	{
		AssetHandle handle = .(assetId);
		Asset asset = Content.GetAsset(handle, blocking: true);

		if (asset == null)
		{
			ThrowInvalidOperationException(scope $"No asset exists for AssetHandle \"{assetId}\".");
		}

		asset
	}*/

	static void SetExceptionMessage(StringView message)
	{
		_lastExceptionMessage.Set(message);
	}

	static mixin GetAssetOrReturn<T>(UUID assetId) where T : Asset
	{
		AssetHandle handle = .(assetId);
		T asset = Content.GetAsset<T>(handle, blocking: true);

		if (asset == null)
		{
			SetExceptionMessage(scope $"Asset (Id: {assetId}) not found.");
			return EngineResult.AssetNotFound;
		}

		asset
	}

	static mixin GetAssetOrReturn<T>(AssetHandle assetHandle) where T : Asset
	{
		T asset = Content.GetAsset<T>(assetHandle, blocking: true);

		if (asset == null)
		{
			SetExceptionMessage(scope $"Asset (Handle: {assetHandle}) not found.");
			return EngineResult.AssetNotFound;
		}

		asset
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Asset_GetIdentifier(UUID assetId, out StringView identifier)
	{
		identifier = ?;
		Asset asset = GetAssetOrReturn!<Asset>(assetId);

		identifier = asset.Identifier;
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Asset_SetIdentifier(UUID assetId, StringView identifier)
	{
		return .NotImplemented;

		//AssetHandle handle = .(assetId);
		//Asset asset = Content.GetAsset(handle, blocking: true);

		//ThrowNotImplementedException("Asset.GetIdentifier is not implemented.");

		/*
		// TODO: I think it's not THAT easy.
		asset.Identifier = StringView(rawText);
		*/
	}

#endregion

#region Material
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Material_SetVariable(AssetHandle assetHandle, StringView variableName, ShaderVariableType elementType, int32 rows, int32 columns, int32 arrayLength, void* rawData, int32 dataLength)
	{
		Material material = GetAssetOrReturn!<Material>(assetHandle);

		if (material.[Friend]SetVariableRaw(variableName, elementType, rows, columns , arrayLength, Span<uint8>((uint8*)rawData, dataLength)) case .Err(let error))
		{
			switch (error)
			{
			case .VariableNotFound:
				SetExceptionMessage(scope $"Material \"{material.Identifier}\" has no variable \"{variableName}\".");
				return .ArgumentError;
			case .ElementTypeMismatch:
				SetExceptionMessage(scope $"Variable \"{variableName}\" has incompatible element type.");
				return .ArgumentError;
			case .MatrixDimensionMismatch:
				SetExceptionMessage(scope $"Variable \"{variableName}\" has incompatible matrix dimension type.");
				return .ArgumentError;
			case .ProvidedBufferTooShort:
				SetExceptionMessage(scope $"The provided data buffer for variable \"{variableName}\" is not large enough.");
			}
			return .Error;
		}
		
		return .Ok;
	}
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Material_ResetVariable(AssetHandle assetHandle, StringView variableName)
	{
		Material material = GetAssetOrReturn!<Material>(assetHandle);

		material.ResetVariable(variableName);
		
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Material_SetTexture(AssetHandle materialHandle, StringView variableName, AssetHandle textureHandle)
	{
		Material material = GetAssetOrReturn!<Material>(materialHandle);

		material.SetTexture(variableName, textureHandle);
		
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Material_GetTexture(AssetHandle materialHandle, StringView variableName, out AssetHandle textureHandle)
	{
		textureHandle = ?;
		Material material = GetAssetOrReturn!<Material>(materialHandle);

		var v = material.GetTexture(variableName, ?);

		if (v case .Err(let err))
		{
			return .Error;
		}

		textureHandle = v.Value;
		
		return .Ok;
	}

	[RegisterCall, CallingConvention(.Cdecl)]
	static EngineResult Material_ResetTexture(AssetHandle materialHandle, StringView variableName)
	{
		Material material = GetAssetOrReturn!<Material>(materialHandle);

		material.ResetTexture(variableName);

		return .Ok;
	}

#endregion

#region ImGui Extension
	
	[RegisterCall, CallingConvention(.Cdecl)]
	static void ImGuiExtension_ListElementGrabber()
	{
		ImGui.ImGui.ListElementGrabber();
	}

#endregion
}
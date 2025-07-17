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

struct RegisterCallAttribute : Attribute
{
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
	private static readonly Dictionary<String, String> BeefToCsharpTypeMap = new .()
	{
		("int32", "int"),
		("char16*", "char*"),
		("char8*", "byte*"),
		("uint8*", "byte*"),
		("GlitchyEngine.Events.MouseButton", "GlitchyEngine.MouseButton"),
		("GlitchLog.LogLevel", "Log.LogLevel"),
		("out GlitchyEngine.Content.AssetHandle", "UUID"),
		("GlitchyEngine.Content.AssetHandle", "UUID"),
		("out GlitchyEngine.Renderer.Text.FontRenderer.HorizontalTextAlignment", "HorizontalTextAlignment"),
		("GlitchyEngine.Renderer.Text.FontRenderer.HorizontalTextAlignment", "HorizontalTextAlignment"),
		("GlitchyEngine.Renderer.ShaderVariableType", "Material.ShaderVariableType"),
		("in GlitchyEngine.Math.Quaternion", "in System.Numerics.Quaternion"),
		("out GlitchyEngine.Math.Quaternion", "out System.Numerics.Quaternion"),
		("out GlitchyEngine.Scripting.ScriptGlue.AxisAngle", "out RotationAxisAngle"),
		("GlitchyEngine.Scripting.ScriptGlue.AxisAngle", "RotationAxisAngle"),
		("out GlitchyEngine.World.Rigidbody2DComponent.BodyType", "out BodyType"),
		("in GlitchyEngine.World.Rigidbody2DComponent.BodyType", "in BodyType"),
		("out GlitchyEngine.World.SceneCamera.ProjectionType", "out ProjectionType"),
		("in GlitchyEngine.World.SceneCamera.ProjectionType", "in ProjectionType"),
	};

	// {0}... Out name, 
	// {1}... In name
	private static readonly Dictionary<String, TypeTranslationTemplate> BeefTypeToCSharpWrapperTemplate = new .()
	{
		("char8*", .("byte* {0} = (byte*)Marshal.StringToCoTaskMemUTF8({1});", "Marshal.FreeCoTaskMem((IntPtr){0});", "string")),
		("char16*", .("fixed (char* {0} = {1})\n{{", "}}", "string")),
	};
	
	private static readonly Dictionary<String, TypeTranslationTemplate> CSharpTypeToReturnValueTemplate = new .()
	{
		("void", .("", "", "void")),
	};

	private static String GetCSharpInterfaceType(String beefType)
	{
		if (BeefToCsharpTypeMap.TryGetValueAlt(beefType, let csharpType))
		{
			return csharpType;
		}

		return beefType;
	}

	private static TypeTranslationTemplate GetCSharpWrapperTemplate(String beefType)
	{
		if (BeefTypeToCSharpWrapperTemplate.TryGetValueAlt(beefType, let template))
		{
			return template;
		}
		
		return .("", "", GetCSharpInterfaceType(beefType));
	}

	private static TypeTranslationTemplate GetCSharpReturnValueTemplate(String beefType)
	{
		if (CSharpTypeToReturnValueTemplate.TryGetValueAlt(beefType, let template))
		{
			return template;
		}

		return .("var returnValue = ", "return returnValue;", GetCSharpInterfaceType(beefType));
	}

	private static void GenerateCSharpFunctionPointer(MethodInfo method, String outString)
	{
		String parameters = new String();

		for (int i < method.ParamCount)
		{
			if (i != 0)
				parameters.Append(", ");

			String typeHolder = scope String();

			method.GetParamType(i).ToString(typeHolder);

			StringView csharpType = GetCSharpInterfaceType(typeHolder);

			parameters.AppendF($"{csharpType}");
		}
		
		String csharpFunctionPointer = scope $"    public delegate* unmanaged[Cdecl]<{parameters}{(parameters.IsEmpty ? "" : ", ")}{method.ReturnType}> {method.Name};\n";
		outString.Append(csharpFunctionPointer);
	}
	
	private static void GenerateCSharpWrapperMethod(MethodInfo method, String outString)
	{
		String wrapperParameters = new .();

		String callArguments = new .();

		String translation = new .();
		String cleanup = new .();

		for (int i < method.ParamCount)
		{
			String beefParameterType = scope String();
			method.GetParamType(i).ToString(beefParameterType);

			TypeTranslationTemplate template = GetCSharpWrapperTemplate(beefParameterType);

			// TODO: This is currently not implemented in beef.
			/*if (method.GetParamCustomAttribute<GlueParamAttribute>(i) case .Ok(let attribute))
			{
				template.PrettyCSharpParamType = attribute.WrapperType;
			}*/

			StringView paramName = method.GetParamName(i);

			// Generate the parameter for the wrapper head.
			{
				if (i != 0)
					wrapperParameters.Append(", ");

				wrapperParameters.AppendF($"{template.PrettyCSharpParamType} {paramName}");
			}

			{
				if (i != 0)
					callArguments.Append(", ");

				String translatedParamName = new String(paramName);

				if (!template.StartCode.IsEmpty)
				{
					translatedParamName.Append("Converted");

					callArguments.AppendF($"{translatedParamName}");
					
					translation.AppendF(template.StartCode, translatedParamName, paramName);
					translation.Append('\n');
				}
				else
				{
					callArguments.AppendF($"{paramName}");
				}

				if (!template.EndCode.IsEmpty)
				{
					cleanup.AppendF(template.EndCode, translatedParamName, paramName);
					cleanup.Append('\n');
				}
			}
		}

		String returnTypeName = new .();
		method.ReturnType.ToString(returnTypeName);
		String csharpReturnType = GetCSharpInterfaceType(returnTypeName);
		TypeTranslationTemplate template = GetCSharpReturnValueTemplate(csharpReturnType);

		outString.AppendF($"""
			internal static unsafe {template.PrettyCSharpParamType} {method.Name}({wrapperParameters})
			{{
				{translation}
				{template.StartCode}_engineFunctions.{method.Name}({callArguments});

				{cleanup}
				{template.EndCode}
			}}


			""");
	}

	private static String GetTypeInfo(Type type)
	{
		String value = new .();
		type.ToString(value);

		if (type.IsEnum)
		{
			value.AppendF($" : {type.UnderlyingType}");
		}

		return value;
	}
	
	private static void GenerateJsonInfo(MethodInfo method, String outString)
	{
		String parameters = new String();

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
					"return_type": "{GetTypeInfo(method.ReturnType)}",
					"parameters": [{parameters}
					]
				}},
			""");
	}

	[Comptime]
	public void ApplyToType(Type self)
    {
		String csharpEngineFunctionsStruct = new String("""
			using System;
			using System.Runtime.InteropServices;
			using GlitchyEngine;
			using GlitchyEngine.Core;
			using GlitchyEngine.Math;
			using GlitchyEngine.Physics;
			using GlitchyEngine.Graphics;
			using GlitchyEngine.Graphics.Text;

			namespace GlitchyEngine;

			internal unsafe partial struct EngineFunctions
			{

			""");

		String csharpScriptGlue = new String("""


			internal static partial class ScriptGlue
			{

			""");

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

				String line = scope $"public function {methodInfo.ReturnType}({parameters}) {methodInfo.Name};\n";

				Compiler.EmitTypeBody(self, line);

				GenerateCSharpFunctionPointer(methodInfo, csharpEngineFunctionsStruct);
				
				GenerateCSharpWrapperMethod(methodInfo, csharpScriptGlue);
				GenerateJsonInfo(methodInfo, jsonOutput);
			}
		}

		csharpEngineFunctionsStruct.Append('}');
		csharpScriptGlue.Append('}');

		csharpEngineFunctionsStruct.Append(csharpScriptGlue);

		/*if (File.WriteAllText("../ScriptCore/ScriptGlue.gen.cs", csharpEngineFunctionsStruct) case .Err)
		{
			Runtime.FatalError("Failed to write file");
		}*/

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
}

static class ScriptGlue
{
	/*private static Dictionary<MonoType*, function void(Entity entityId)> s_AddComponentMethods = new .() ~ delete _;
	private static Dictionary<MonoType*, function bool(Entity entityId)> s_HasComponentMethods = new .() ~ delete _;
	private static Dictionary<MonoType*, function void(Entity entityId)> s_RemoveComponentMethods = new .() ~ delete _;*/

	/* Adding this attribute to a method will log method entry and returned Result<T> errors */
	[AttributeUsage(.Method)]
	struct RegisterMethodAttribute : Attribute, IOnMethodInit
	{
	    [Comptime]
	    public void OnMethodInit(MethodInfo method, Self* prev)
	    {
			String functionContent = new .();

			int i = 0;

	        for (var methodInfo in typeof(ScriptGlue).GetMethods(.Static))
			{
				if (methodInfo.GetCustomAttribute<RegisterCallAttribute>() case .Ok(let attribute))
				{
					functionContent.AppendF($"functions.{methodInfo.Name} = => {methodInfo.Name};\n");
					//functionContent.AppendF($"functions[{i}] = (void*)( => {methodInfo.Name});\n");
					i++;
				}
			}

			functionContent.Insert(0, scope $"EngineFunctions functions = .();\n");

			functionContent.Append("_setEngineFunctions(&functions);");

			Compiler.EmitMethodEntry(method, functionContent);
	    }
	}


	public static Event<delegate void()> OnRegisterNativeCalls ~ _.Dispose();

	/*private function void SetEngineFunctions(EngineFunctions* engineFunctions);
	private static SetEngineFunctions _setEngineFunctions;*/

	private function void SetEngineFunctions(EngineFunctions* engineFunctions);
	private static SetEngineFunctions _setEngineFunctions;

	public static void Init()
	{
		if (_setEngineFunctions == null)
		{
			CoreClrHelper.GetFunctionPointerUnmanagedCallersOnly("GlitchyEngine.ScriptGlue, ScriptCore", "SetEngineFunctions", out _setEngineFunctions);
		}

		RegisterCalls();

		//RegisterMathFunctions();
	}

	public static void RegisterManagedComponents()
	{
		Debug.Profiler.ProfileFunction!();

		/*s_AddComponentMethods.Clear();
		s_HasComponentMethods.Clear();
		s_RemoveComponentMethods.Clear();*/

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
		FillEngineFunctions();

		OnRegisterNativeCalls.Invoke();
	}
	
	[RegisterMethod]
	private static void FillEngineFunctions()
	{

	}

	private static void RegisterComponent<T>() where T : struct, new
	{
		Log.EngineLogger.Error("ScriptGlue::RegisterComponent not updated yet.");

		String fullComponentTypeName = scope String();
		typeof(T).GetFullName(fullComponentTypeName);

		CoreClrHelper.RegisterComponent(fullComponentTypeName,
			addComponent: (entityId) => {
					Entity entity = GetEntitySafe(entityId);
					entity.AddComponent<T>();
				},
			hasComponent: (entityId) => {
					Entity entity = GetEntitySafe(entityId);
					return entity.HasComponent<T>();
				},
			removeComponent: (entityId) => {
					Entity entity = GetEntitySafe(entityId);
					entity.RemoveComponent<T>();
				});
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

	/// Throws an ArgumentException in the mono runtime.
	[NoReturn]
	static void ThrowArgumentException(char8* argument, char8* message)
	{

		//MonoException* exception = Mono.mono_get_exception_argument(argument, message);
		//Mono.mono_raise_exception(exception);
	}
	
	/// Throws an InvalidOperationException in the mono runtime.
	[NoReturn]
	static void ThrowInvalidOperationException(char8* message)
	{
		//MonoException* exception = Mono.mono_get_exception_invalid_operation(message);
		//Mono.mono_raise_exception(exception);
	}
	
	/// Throws an NotImplementedException in the mono runtime.
	[NoReturn]
	static void ThrowNotImplementedException(StringView message)
	{
		//MonoException* exception = Mono.mono_get_exception_invalid_operation(message);
		//Mono.mono_raise_exception(exception);
		CoreClrHelper.ThrowException(message);
	}

#endregion
	
#region Log

	[RegisterCall]
	//[CallingConvention(.Cdecl)]
	static void Log_LogMessage(LogLevel logLevel, char8* messagePtr, char8* fileNamePtr, int lineNumber)
	{
		String escapedMessage = new:ScopedAlloc! String(messagePtr);

		// Why exactly do we have to replace these? Can we get away without copying the string above?
		escapedMessage.Replace("{", "{{");
		escapedMessage.Replace("}", "}}");

		if (escapedMessage == "Exception")
		{
			ThrowNotImplementedException("Test exception");
		}

		if (fileNamePtr != null)
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

	[RegisterCall]
	static void Log_LogException(UUID entityId, char8* fullExceptionClassName, char8* exceptionMessage, char8* stackTrace)
	{
		ScriptException exception = new ScriptException(entityId, StringView(fullExceptionClassName), StringView(exceptionMessage), StringView(stackTrace));

		ScriptEngine.LogScriptException(exception, entityId);
	}

#endregion

#region Input

	[RegisterCall]
	static bool Input_IsKeyPressed(Key key) => Input.IsKeyPressed(key);

	[RegisterCall]
	static bool Input_IsKeyReleased(Key key) => Input.IsKeyReleased(key);
	
	[RegisterCall]
	static bool Input_IsKeyToggled(Key key) => Input.IsKeyToggled(key);

	[RegisterCall]
	static bool Input_IsKeyPressing(Key key) => Input.IsKeyPressing(key);

	[RegisterCall]
	static bool Input_IsKeyReleasing(Key key) => Input.IsKeyReleasing(key);

	
	[RegisterCall]
	static bool Input_IsMouseButtonPressed(MouseButton mouseButton) => Input.IsMouseButtonPressed(mouseButton);

	[RegisterCall]
	static bool Input_IsMouseButtonReleased(MouseButton mouseButton) => Input.IsMouseButtonReleased(mouseButton);

	[RegisterCall]
	static bool Input_IsMouseButtonPressing(MouseButton mouseButton) => Input.IsMouseButtonPressing(mouseButton);

	[RegisterCall]
	static bool Input_IsMouseButtonReleasing(MouseButton mouseButton) => Input.IsMouseButtonReleasing(mouseButton);

#endregion Input

#region Scene/Entity stuff

	[RegisterCall]
	static void Entity_Create(char8* entityName, out UUID entityId)
	{
		Entity entity = ScriptEngine.Context.CreateEntity(StringView(entityName));

		entityId = entity.UUID;
	}

	[RegisterCall]
	static void Entity_Destroy(UUID entityId)
	{
		Entity entity = GetEntitySafe(entityId);
		ScriptEngine.Context.DestroyEntityDeferred(entity);
	}

	[RegisterCall]
	static void Entity_CreateInstance(UUID entityId, out UUID newEntityId)
	{
		Entity entity = GetEntitySafe(entityId);
		Entity newEntity = ScriptEngine.Context.CreateInstance(entity);

		newEntityId = newEntity.UUID;
	}
	
	[RegisterCall]
	static void Entity_FindEntityWithName(char8* entityName, out UUID outUuid)
	{
		outUuid = UUID(0);

		StringView nameString = StringView(entityName);

		Result<Entity> entityResult = ScriptEngine.Context.GetEntityByName(nameString);

		if (entityResult case .Ok(let entity))
			outUuid = entity.UUID;
	}

	// TODO: Do we need this?
	[RegisterCall]
	static void Entity_GetScriptInstance(UUID entityId, out void* instance)
	{
		ThrowNotImplementedException("Entity_AddComponents");
		//instance = ScriptEngine.GetManagedInstance(entityId);
	}

	[RegisterCall]
	static bool Entity_SetScript(UUID entityId, char8* fullScriptTypeName)
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

		scriptComponent.ScriptClassName = StringView(fullScriptTypeName);
		
		// Initializes the created instance
		// TODO: this returns false, if no script with ScriptClassName exists, we have to handle this case correctly I think.
		if (!ScriptEngine.InitializeInstance(entity, scriptComponent))
		{
			ThrowNotImplementedException("Werfe eine vernünftige Exception, bitte");
		}

		//return scriptComponent.Instance.MonoInstance;
		return true;
	}
	
	[RegisterCall]
	static void Entity_RemoveScript(UUID entityId)
	{
		ScriptComponent* scriptComponent = GetComponentSafe<ScriptComponent>(entityId);

		ScriptEngine.Context.DestroyScriptDeferred(scriptComponent.Instance, true);
	}
	
	[RegisterCall]
    static char8* Entity_GetName(UUID entityId)
	{
		Result<Entity> foundEntity = ScriptEngine.Context.GetEntityByID(entityId);

		if (foundEntity case .Ok(let entity))
		{
			return entity.Name.Ptr;
		}

		return null;
	}
    
	[RegisterCall]
    static void Entity_SetName(UUID entityId, char8* name)
	{
		Entity entity = ScriptEngine.Context.GetEntityByID(entityId);

		entity.Name = StringView(name);
	}
	
	[RegisterCall]
    static void Entity_GetEditorFlags(UUID entityId, out EditorFlags editorFlags)
	{
		editorFlags = .Default;
#if GE_EDITOR
		if (TryGetEntitySafe(entityId, let entity))
			editorFlags = entity.EditorFlags;
#endif
	}
	
	[RegisterCall]
    static void Entity_SetEditorFlags(UUID entityId, EditorFlags editorFlags)
	{
#if GE_EDITOR
		if (TryGetEntitySafe(entityId, let entity))
			entity.EditorFlags = editorFlags;
#endif
	}

#endregion

#region TransformComponen

	[RegisterCall]
	static void Transform_GetParent(UUID entityId, out UUID parentId)
	{
		Entity entity = GetEntitySafe(entityId);

		parentId = entity.Parent?.UUID ?? .Zero;
	}

	[RegisterCall]
	static void Transform_SetParent(UUID entityId, in UUID parentId)
	{
		Entity entity = GetEntitySafe(entityId);

		Entity? parent = GetEntitySafe(parentId);

		entity.Parent = parent;
	}
	
	[RegisterCall]
	static void Transform_GetTranslation(UUID entityId, out float3 translation)
	{
		Entity entity = GetEntitySafe(entityId);

		translation = entity.Transform.Position;
	}

	[RegisterCall]
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

	[RegisterCall]
	static void Transform_GetWorldTranslation(UUID entityId, out float3 translationWorld)
	{
		Entity entity = GetEntitySafe(entityId);

		TransformComponent* transform = entity.Transform;

		translationWorld = transform.WorldTransform.Translation; //(float4(entity.Transform.Position, 1.0f) * entity.Transform.WorldTransform).XYZ;
	}

	[RegisterCall]
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

	[RegisterCall]
	static void Transform_TransformPointToWorld(UUID entityId, float3 point, out float3 pointWorld)
	{
		Entity entity = GetEntitySafe(entityId);

		float3 localPoint = entity.Transform.Position;

		pointWorld = (float4(localPoint, 1.0f) * entity.Transform.WorldTransform).XYZ;
	}
	
	[RegisterCall]
	static void Transform_GetRotation(UUID entityId, out Quaternion rotation)
	{
		Entity entity = GetEntitySafe(entityId);

		rotation = entity.Transform.Rotation;
	}

	[RegisterCall]
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
	
	[RegisterCall]
	static void Transform_GetRotationEuler(UUID entityId, out float3 rotationEuler)
	{
		Entity entity = GetEntitySafe(entityId);

		rotationEuler = entity.Transform.RotationEuler;
	}

	[RegisterCall]
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

	[RegisterCall]
	static void Transform_GetRotationAxisAngle(UUID entityId, out AxisAngle rotationAxisAngle)
	{
		Entity entity = GetEntitySafe(entityId);

		rotationAxisAngle = AxisAngle(entity.Transform.RotationAxisAngle);
	}

	[RegisterCall]
	static void Transform_SetRotationAxisAngle(UUID entityId, AxisAngle rotationAxisAngle)
	{
		Entity entity = GetEntitySafe(entityId);
		
		entity.Transform.RotationAxisAngle = (rotationAxisAngle.Axis, rotationAxisAngle.Angle);

		if (entity.TryGetComponent<Rigidbody2DComponent>(let rigidbody2D))
		{
			rigidbody2D.SetAngle(entity.Transform.RotationEuler.Z);
		}
	}

	[RegisterCall]
	static void Transform_GetScale(UUID entityId, out float3 scale)
	{
		Entity entity = GetEntitySafe(entityId);

		scale = entity.Transform.Scale;
	}

	[RegisterCall]
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

#region Rigidbody2
	
	[RegisterCall]
	static void Rigidbody2D_ApplyForce(UUID entityId, in float2 force, in float2 point, bool wakeUp)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		Box2D.Body.ApplyForce(rigidBody.[Friend]RuntimeBody, force, point, wakeUp);
	}
	
	[RegisterCall]
	static void Rigidbody2D_ApplyForceToCenter(UUID entityId, in float2 force, bool wakeUp)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		Box2D.Body.ApplyForceToCenter(rigidBody.[Friend]RuntimeBody, force, wakeUp);
	}

	[RegisterCall]
	static void Rigidbody2D_SetPosition(UUID entityId, in float2 position)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetPosition(position);
	}

	[RegisterCall]
	static void Rigidbody2D_GetPosition(UUID entityId, out float2 position)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		position = rigidBody.GetPosition();
	}
	
	[RegisterCall]
	static void Rigidbody2D_SetRotation(UUID entityId, in float rotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetAngle(rotation);
	}

	[RegisterCall]
	static void Rigidbody2D_GetRotation(UUID entityId, out float rotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rotation = rigidBody.GetAngle();
	}

	[RegisterCall]
	static void Rigidbody2D_GetLinearVelocity(UUID entityId, out float2 velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		velocity = rigidBody.GetLinearVelocity();
	}
	
	[RegisterCall]
	static void Rigidbody2D_SetLinearVelocity(UUID entityId, in float2 velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetLinearVelocity(velocity);
	}

	[RegisterCall]
	static void Rigidbody2D_GetAngularVelocity(UUID entityId, out float velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		velocity = rigidBody.GetAngularVelocity();
	}
	
	[RegisterCall]
	static void Rigidbody2D_SetAngularVelocity(UUID entityId, in float velocity)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.SetAngularVelocity(velocity);
	}

	[RegisterCall]
	static void Rigidbody2D_GetBodyType(UUID entityId, out Rigidbody2DComponent.BodyType bodyType)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		bodyType = rigidBody.BodyType;
	}
	
	[RegisterCall]
	static void Rigidbody2D_SetBodyType(UUID entityId, in Rigidbody2DComponent.BodyType bodyType)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.BodyType = bodyType;
	}

	[RegisterCall]
	static void Rigidbody2D_IsFixedRotation(UUID entityId, out bool isFixedRotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		isFixedRotation = rigidBody.FixedRotation;
	}
	
	[RegisterCall]
	static void Rigidbody2D_SetFixedRotation(UUID entityId, in bool isFixedRotation)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.FixedRotation = isFixedRotation;
	}

	[RegisterCall]
	static void Rigidbody2D_GetGravityScale(UUID entityId, out float gravityScale)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		gravityScale = rigidBody.GravityScale;
	}
	
	[RegisterCall]
	static void Rigidbody2D_SetGravityScale(UUID entityId, in float gravityScale)
	{
		Rigidbody2DComponent* rigidBody = GetComponentSafe<Rigidbody2DComponent>(entityId);
		rigidBody.GravityScale = gravityScale;
	}

#endregion Rigidbody2D

#region Camer

	[RegisterCall]
	static void Camera_GetProjectionType(UUID entityId, out SceneCamera.ProjectionType projectionType)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		projectionType = camera.Camera.ProjectionType;
	}
	
	[RegisterCall]
	static void Camera_SetProjectionType(UUID entityId, in SceneCamera.ProjectionType projectionType)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.ProjectionType = projectionType;
	}

	[RegisterCall]
	static void Camera_GetPerspectiveFovY(UUID entityId, out float fovY)
	{
	    CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		fovY = camera.Camera.PerspectiveFovY;
	}

	[RegisterCall]
	static void Camera_SetPerspectiveFovY(UUID entityId, float fovY)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.PerspectiveFovY = fovY;
	}

	[RegisterCall]
	static void Camera_GetPerspectiveNearPlane(UUID entityId, out float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		nearPlane = camera.Camera.PerspectiveNearPlane;
	}

	[RegisterCall]
	static void Camera_SetPerspectiveNearPlane(UUID entityId, float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.PerspectiveNearPlane = nearPlane;
	}

	[RegisterCall]
	static void Camera_GetPerspectiveFarPlane(UUID entityId, out float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		farPlane = camera.Camera.PerspectiveFarPlane;
	}

	[RegisterCall]
	static void Camera_SetPerspectiveFarPlane(UUID entityId, float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.PerspectiveFarPlane = farPlane;
	}

	[RegisterCall]
	static void Camera_GetOrthographicHeight(UUID entityId, out float height)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		height = camera.Camera.OrthographicHeight;
	}

	[RegisterCall]
	static void Camera_SetOrthographicHeight(UUID entityId, float height)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.OrthographicHeight = height;
	}

	[RegisterCall]
	static void Camera_SetOrthographicNearPlane(UUID entityId, float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.OrthographicNearPlane = nearPlane;
	}

	[RegisterCall]
	static void Camera_GetOrthographicNearPlane(UUID entityId, out float nearPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		nearPlane = camera.Camera.OrthographicNearPlane;
	}

	[RegisterCall]
	static void Camera_SetOrthographicFarPlane(UUID entityId, float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.OrthographicFarPlane = farPlane;
	}

	[RegisterCall]
	static void Camera_GetOrthographicFarPlane(UUID entityId, out float farPlane)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		farPlane = camera.Camera.OrthographicFarPlane;
	}

	[RegisterCall]
	static void Camera_SetAspectRatio(UUID entityId, float aspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.AspectRatio = aspectRatio;
	}

	[RegisterCall]
	static void Camera_GetAspectRatio(UUID entityId, out float aspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		aspectRatio = camera.Camera.AspectRatio;
	}

	[RegisterCall]
	static void Camera_SetFixedAspectRatio(UUID entityId, bool fixedAspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		camera.Camera.FixedAspectRatio = fixedAspectRatio;
	}

	[RegisterCall]
	static void Camera_GetFixedAspectRatio(UUID entityId, out bool fixedAspectRatio)
	{
		CameraComponent* camera = GetComponentSafe<CameraComponent>(entityId);
		fixedAspectRatio = camera.Camera.FixedAspectRatio;
	}

#endregion

#region Physics2D

	// TODO: We need a wrapper class!

	[RegisterCall]
	static void Physics2D_GetGravity(out float2 gravity)
	{
		Scene scene = ScriptEngine.Context;

		gravity = scene.Physics2DSettings.Gravity;
	}

	[RegisterCall]
	static void Physics2D_SetGravity(in float2 gravity)
	{
		Scene scene = ScriptEngine.Context;

		scene.Physics2DSettings.Gravity = gravity;
	}

#endregion Physics2D

#region CircleRenderer
	
	[RegisterCall]
	static void CircleRenderer_GetColor(UUID entityId, out ColorRGBA color)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		color = circleRenderer.Color;
	}

	[RegisterCall]
	static void CircleRenderer_SetColor(UUID entityId, ColorRGBA color)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		circleRenderer.Color = color;
	}
	
	[RegisterCall]
	static void CircleRenderer_GetUvTransform(UUID entityId, out float4 uvTransform)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		uvTransform = circleRenderer.UvTransform;
	}

	[RegisterCall]
	static void CircleRenderer_SetUvTransform(UUID entityId, float4 uvTransform)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		circleRenderer.UvTransform = uvTransform;
	}
	
	[RegisterCall]
	static void CircleRenderer_GetInnerRadius(UUID entityId, out float innerRadius)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		innerRadius = circleRenderer.InnerRadius;
	}

	[RegisterCall]
	static void CircleRenderer_SetInnerRadius(UUID entityId, float innerRadius)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		circleRenderer.InnerRadius = innerRadius;
	}

#endregion

#region SpriteRenderer

	[RegisterCall]
	static void SpriteRenderer_GetColor(UUID entityId, out ColorRGBA color)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);
		color = spriteRenderer.Color;
	}

	[RegisterCall]
	static void SpriteRenderer_SetColor(UUID entityId, ColorRGBA color)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);
		spriteRenderer.Color = color;
	}
	
	[RegisterCall]
	static void SpriteRenderer_GetUvTransform(UUID entityId, out float4 uvTransform)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);
		uvTransform = spriteRenderer.UvTransform;
	}

	[RegisterCall]
	static void SpriteRenderer_SetUvTransform(UUID entityId, float4 uvTransform)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);
		spriteRenderer.UvTransform = uvTransform;
	}
	
	[RegisterCall]
	static void SpriteRenderer_GetMaterial(UUID entityId, out AssetHandle assetId)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);

		Material material = GetAssetOrThrow!<Material>((AssetHandle)spriteRenderer.Material);

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
	}

	[RegisterCall]
	static void SpriteRenderer_SetMaterial(UUID entityId, AssetHandle assetId)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);
		spriteRenderer.Material = assetId;
	}


#endregion

#region TextRenderer

	[RegisterCall]
	static bool TextRenderer_GetIsRichText(UUID entityId)
	{
		return GetComponentSafe<TextRendererComponent>(entityId).IsRichText;
	}

	[RegisterCall]
	static void TextRenderer_SetIsRichText(UUID entityId, bool isRichText)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);

		textComponent.IsRichText = isRichText;
		textComponent.NeedsRebuild = true;
	}

	[RegisterCall]
	static void TextRenderer_GetText(UUID entityId, out char8* text)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);

		text = textComponent.Text.Ptr;
	}

	[RegisterCall]
	static void TextRenderer_SetText(UUID entityId, char8* text)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);

		textComponent.Text = StringView(text);

		textComponent.NeedsRebuild = true;
	}

	[RegisterCall]
	static void TextRenderer_GetColor(UUID entityId, out ColorRGBA color)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		color = textComponent.Color;
	}

	[RegisterCall]
	static void TextRenderer_SetColor(UUID entityId, ColorRGBA color)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		textComponent.Color = color;
		textComponent.NeedsRebuild = true;
	}

	[RegisterCall]
	static void TextRenderer_GetHorizontalAlignment(UUID entityId, [GlueParam("out HorizontalTextAlignment")] out HorizontalTextAlignment horizontalAlignment)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		horizontalAlignment = textComponent.HorizontalAlignment;
	}

	[RegisterCall]
	static void TextRenderer_SetHorizontalAlignment(UUID entityId, [GlueParam("HorizontalTextAlignment")] HorizontalTextAlignment horizontalAlignment)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		textComponent.HorizontalAlignment = horizontalAlignment;
		textComponent.NeedsRebuild = true;
	}
	
	[RegisterCall]
	static void TextRenderer_GetFontSize(UUID entityId, out float fontSize)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		fontSize = textComponent.FontSize;
	}

	[RegisterCall]
	static void TextRenderer_SetFontSize(UUID entityId, float fontSize)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		textComponent.FontSize = fontSize;
		textComponent.NeedsRebuild = true;
	}

#endregion

#region Mesh
#endregion

#region MeshRenderer

	[RegisterCall]
	static void MeshRenderer_GetMaterial(UUID entityId, out AssetHandle assetId)
	{
		MeshRendererComponent* meshRenderer = GetComponentSafe<MeshRendererComponent>(entityId);

		Material material = GetAssetOrThrow!<Material>((AssetHandle)meshRenderer.Material);
		
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
	}

	[RegisterCall]
	static void MeshRenderer_GetSharedMaterial(UUID entityId, out AssetHandle assetId)
	{
		MeshRendererComponent* meshRenderer = GetComponentSafe<MeshRendererComponent>(entityId);
		
		Material material = GetAssetOrThrow!<Material>((AssetHandle)meshRenderer.Material);

		if (material.IsRuntimeInstance)
		{
			assetId = material.Parent.Handle;
		}
		else
		{
			assetId = meshRenderer.Material;
		}
	}

	[RegisterCall]
	static void MeshRenderer_SetMaterial(UUID entityId, AssetHandle assetId)
	{
		MeshRendererComponent* meshRenderer = GetComponentSafe<MeshRendererComponent>(entityId);
		meshRenderer.Material = assetId;
	}

#endregion

#region Math
	
	[RegisterCall]
	static float Math_ModfFloat(float x, out float integerPart)
	{
		return modf(x, out integerPart);
	}

	[RegisterCall]
	static float2 Math_ModfFloat2(float2 x, out float2 integerPart)
	{
		return modf(x, out integerPart);
	}

	[RegisterCall]
	static float3 Math_ModfFloat3(float3 x, out float3 integerPart)
	{
		return modf(x, out integerPart);
	}

	[RegisterCall]
	static float4 Math_ModfFloat4(float4 x, out float4 integerPart)
	{
		return modf(x, out integerPart);
	}

#endregion

	[RegisterCall]
	static void UUID_Create(out UUID id)
	{
		id = UUID.Create();
	}

#region Application
	
	[RegisterCall]
	static bool Application_IsEditor()
	{
		return ScriptEngine.ApplicationInfo.IsEditor;
	}

	[RegisterCall]
	static bool Application_IsPlayer()
	{
		return ScriptEngine.ApplicationInfo.IsPlayer;
	}

	[RegisterCall]
	static bool Application_IsInEditMode()
	{
		return ScriptEngine.ApplicationInfo.IsInEditMode;
	}

	[RegisterCall]
	static bool Application_IsInPlayMode()
	{
		return ScriptEngine.ApplicationInfo.IsInPlayMode;
	}

#endregion

#region Serialization

	[RegisterCall]
	static void Serialization_SerializeField(void* serializationContext, SerializationType type, char8* fieldName, void* valueObject, char8* fullTypeName)
	{
		SerializedObject context = Internal.UnsafeCastToObject(serializationContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);

		context.AddField(StringView(fieldName), type, valueObject, StringView(fullTypeName));
	}
	
	[RegisterCall]
	static void Serialization_CreateObject(void* currentContext, bool isStatic, char8* typeName, out void* newContext, out UUID newId)
	{
		SerializedObject context = Internal.UnsafeCastToObject(currentContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);
		
		SerializedObject newObject = new SerializedObject(context.Serializer, isStatic, StringView(typeName));

		newContext = Internal.UnsafeCastToPtr(newObject);
		newId = newObject.Id;
	}
	
	[RegisterCall]
	public static void Serialization_DeserializeField(void* internalContext, SerializationType expectedType, char8* fieldName, uint8* target, out SerializationType actualType)
	{
		SerializedObject context = Internal.UnsafeCastToObject(internalContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);
		
		context.GetField(StringView(fieldName), expectedType, target, out actualType);
	}
	
	[RegisterCall]
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
	
	[RegisterCall]
	public static void Serialization_GetObjectTypeName(void* internalContext, out char8* fullTypeName)
	{
		SerializedObject context = Internal.UnsafeCastToObject(internalContext) as SerializedObject;

		Log.EngineLogger.AssertDebug(context != null);

		fullTypeName = context.TypeName.CStr();
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

	static mixin GetAssetOrThrow<T>(UUID assetId) where T : Asset
	{
		AssetHandle handle = .(assetId);
		T asset = Content.GetAsset<T>(handle, blocking: true);

		if (asset == null)
		{
			ThrowInvalidOperationException(scope $"No asset exists for AssetHandle \"{assetId}\".");
		}

		asset
	}

	static mixin GetAssetOrThrow<T>(AssetHandle assetHandle) where T : Asset
	{
		T asset = Content.GetAsset<T>(assetHandle, blocking: true);

		if (asset == null)
		{
			ThrowInvalidOperationException(scope $"No asset exists for AssetHandle \"{assetHandle}\".");
		}

		asset
	}

	[RegisterCall]
	static void Asset_GetIdentifier(UUID assetId, out char8* identifier)
	{
		Asset asset = GetAssetOrThrow!<Asset>(assetId);

		identifier = asset.Identifier.Ptr;
	}

	[RegisterCall]
	static void Asset_SetIdentifier(UUID assetId, char8* identifier)
	{
		AssetHandle handle = .(assetId);
		Asset asset = Content.GetAsset(handle, blocking: true);

		ThrowNotImplementedException("Asset.GetIdentifier is not implemented.");

		/*
		// TODO: I think it's not THAT easy.
		asset.Identifier = StringView(rawText);
		*/
	}

#endregion

#region Material
	
	[RegisterCall]
	static void Material_SetVariable(AssetHandle assetHandle, char8* variableName, ShaderVariableType elementType, int32 rows, int32 columns, int32 arrayLength, void* rawData, int32 dataLength)
	{
		Material material = GetAssetOrThrow!<Material>(assetHandle);

		material.[Friend]SetVariableRaw(StringView(variableName), elementType, rows, columns , arrayLength, Span<uint8>((uint8*)rawData, dataLength));
	}
	
	[RegisterCall]
	static void Material_ResetVariable(AssetHandle assetHandle, char8* variableName)
	{
		Material material = GetAssetOrThrow!<Material>(assetHandle);

		material.ResetVariable(StringView(variableName));
	}

	[RegisterCall]
	static void Material_SetTexture(AssetHandle materialHandle, char8* variableName, AssetHandle textureHandle)
	{
		Material material = GetAssetOrThrow!<Material>(materialHandle);

		material.SetTexture(StringView(variableName), textureHandle);
	}

	[RegisterCall]
	static void Material_GetTexture(AssetHandle materialHandle, char8* variableName, out AssetHandle textureHandle)
	{
		Material material = GetAssetOrThrow!<Material>(materialHandle);

		var v = material.GetTexture(StringView(variableName), ?);

		if (v case .Err(let err))
		{
			ThrowInvalidOperationException(scope $"Error while getting texture from material {err}");
		}

		textureHandle = v.Value;
	}

	[RegisterCall]
	static void Material_ResetTexture(AssetHandle materialHandle, char8* variableName)
	{
		Material material = GetAssetOrThrow!<Material>(materialHandle);

		material.ResetTexture(StringView(variableName));
	}

#endregion

#region ImGui Extension
	
	[RegisterCall]
	static void ImGuiExtension_ListElementGrabber()
	{
		ImGui.ImGui.ListElementGrabber();
	}

#endregion
}
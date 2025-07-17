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
using GlitchyEngine.Content;
using GlitchyEngine.Renderer;
using System.Diagnostics;
using System.IO;
using static GlitchyEngine.Renderer.Text.FontRenderer;
using System.Linq;

namespace GlitchyEngine.Scripting;

using internal GlitchyEngine.Scripting;
using internal GlitchyEngine.Content;

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
	public String MethodName;

	public this(String methodName)
	{
		MethodName = methodName;
	}
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
	private static Dictionary<MonoType*, function void(Entity entityId)> s_AddComponentMethods = new .() ~ delete _;
	private static Dictionary<MonoType*, function bool(Entity entityId)> s_HasComponentMethods = new .() ~ delete _;
	private static Dictionary<MonoType*, function void(Entity entityId)> s_RemoveComponentMethods = new .() ~ delete _;

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

		s_AddComponentMethods.Clear();
		s_HasComponentMethods.Clear();
		s_RemoveComponentMethods.Clear();

		RegisterComponent<TransformComponent>("GlitchyEngine.Core.Transform");
		RegisterComponent<Rigidbody2DComponent>("GlitchyEngine.Physics.Rigidbody2D");
		RegisterComponent<CameraComponent>("GlitchyEngine.Core.Camera");
		RegisterComponent<SpriteRendererComponent>("GlitchyEngine.Graphics.SpriteRenderer");
		RegisterComponent<CircleRendererComponent>("GlitchyEngine.Graphics.CircleRenderer");
		RegisterComponent<TextRendererComponent>("GlitchyEngine.Graphics.Text.TextRenderer");
		RegisterComponent<MeshComponent>("GlitchyEngine.Graphics.Mesh");
		RegisterComponent<MeshRendererComponent>("GlitchyEngine.Graphics.MeshRenderer");
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

	/// Throws an ArgumentException in the mono runtime.
	[NoReturn]
	static void ThrowArgumentException(char8* argument, char8* message)
	{
		MonoException* exception = Mono.mono_get_exception_argument(argument, message);
		Mono.mono_raise_exception(exception);
	}
	
	/// Throws an InvalidOperationException in the mono runtime.
	[NoReturn]
	static void ThrowInvalidOperationException(char8* message)
	{
		MonoException* exception = Mono.mono_get_exception_invalid_operation(message);
		Mono.mono_raise_exception(exception);
	}
	
	/// Throws an NotImplementedException in the mono runtime.
	[NoReturn]
	static void ThrowNotImplementedException(char8* message)
	{
		MonoException* exception = Mono.mono_get_exception_invalid_operation(message);
		Mono.mono_raise_exception(exception);
	}

#endregion
	
#region Log

	/*[RegisterCall("ScriptGlue::Log_LogMessage")]
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
	}*/

	[RegisterCall("ScriptGlue::Log_LogMessage")]
	[CallingConvention(.Cdecl)]
	static void Log_LogMessage(LogLevel logLevel, char16* messagePtr, char16* fileNamePtr, int lineNumber)
	{
		String escapedMessage = new:ScopedAlloc! String(messagePtr);

		// Why exactly do we have to replace these? Can we get away without copying the string above?
		escapedMessage.Replace("{", "{{");
		escapedMessage.Replace("}", "}}");

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
	static void Entity_FindEntityWithName(MonoString* monoName, out UUID outUuid)
	{
		outUuid = UUID(0);

		char8* entityName = Mono.mono_string_to_utf8(monoName);

		StringView nameString = StringView(entityName);

		Result<Entity> entityResult = ScriptEngine.Context.GetEntityByName(nameString);

		Mono.mono_free(entityName);

		if (entityResult case .Ok(let entity))
			outUuid = entity.UUID;
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

		//if (scriptComponent.Instance != null)
		//	ScriptEngine.Context.DestroyScriptDeferred(scriptComponent.Instance, false);

		scriptComponent.Instance = null;

		MonoType* type = Mono.mono_reflection_type_get_type(scriptType);

		scriptComponent.ScriptClassName = StringView(Mono.mono_type_full_name(type));
		
		// Initializes the created instance
		// TODO: this returns false, if no script with ScriptClassName exists, we have to handle this case correctly I think.
		ScriptEngine.InitializeInstance(entity, scriptComponent);

		//return scriptComponent.Instance.MonoInstance;
		return null;
	}
	
	[RegisterCall("ScriptGlue::Entity_RemoveScript")]
	static void Entity_RemoveScript(UUID entityId)
	{
		ScriptComponent* scriptComponent = GetComponentSafe<ScriptComponent>(entityId);

		//ScriptEngine.Context.DestroyScriptDeferred(scriptComponent.Instance, true);
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

	[RegisterCall("ScriptGlue::CircleRenderer_SetInnerRadius")]
	static void CircleRenderer_SetInnerRadius(UUID entityId, float innerRadius)
	{
		CircleRendererComponent* circleRenderer = GetComponentSafe<CircleRendererComponent>(entityId);
		circleRenderer.InnerRadius = innerRadius;
	}

#endregion

#region SpriteRenderer

	[RegisterCall("ScriptGlue::SpriteRenderer_GetColor")]
	static void SpriteRenderer_GetColor(UUID entityId, out ColorRGBA color)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);
		color = spriteRenderer.Color;
	}

	[RegisterCall("ScriptGlue::SpriteRenderer_SetColor")]
	static void SpriteRenderer_SetColor(UUID entityId, ColorRGBA color)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);
		spriteRenderer.Color = color;
	}
	
	[RegisterCall("ScriptGlue::SpriteRenderer_GetUvTransform")]
	static void SpriteRenderer_GetUvTransform(UUID entityId, out float4 uvTransform)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);
		uvTransform = spriteRenderer.UvTransform;
	}

	[RegisterCall("ScriptGlue::SpriteRenderer_SetUvTransform")]
	static void SpriteRenderer_SetUvTransform(UUID entityId, float4 uvTransform)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);
		spriteRenderer.UvTransform = uvTransform;
	}
	
	[RegisterCall("ScriptGlue::SpriteRenderer_GetMaterial")]
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

	[RegisterCall("ScriptGlue::SpriteRenderer_SetMaterial")]
	static void SpriteRenderer_SetMaterial(UUID entityId, AssetHandle assetId)
	{
		SpriteRendererComponent* spriteRenderer = GetComponentSafe<SpriteRendererComponent>(entityId);
		spriteRenderer.Material = assetId;
	}


#endregion

#region TextRenderer

	[RegisterCall("ScriptGlue::TextRenderer_GetIsRichText")]
	static bool TextRenderer_GetIsRichText(UUID entityId)
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
	static void TextRenderer_GetHorizontalAlignment(UUID entityId, [GlueParam("out HorizontalTextAlignment")] out HorizontalTextAlignment horizontalAlignment)
	{
		TextRendererComponent* textComponent = GetComponentSafe<TextRendererComponent>(entityId);
		horizontalAlignment = textComponent.HorizontalAlignment;
	}

	[RegisterCall("ScriptGlue::TextRenderer_SetHorizontalAlignment")]
	static void TextRenderer_SetHorizontalAlignment(UUID entityId, [GlueParam("HorizontalTextAlignment")] HorizontalTextAlignment horizontalAlignment)
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

#region Mesh
#endregion

#region MeshRenderer

	[RegisterCall("ScriptGlue::MeshRenderer_GetMaterial")]
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

	[RegisterCall("ScriptGlue::MeshRenderer_GetSharedMaterial")]
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

	[RegisterCall("ScriptGlue::MeshRenderer_SetMaterial")]
	static void MeshRenderer_SetMaterial(UUID entityId, AssetHandle assetId)
	{
		MeshRendererComponent* meshRenderer = GetComponentSafe<MeshRendererComponent>(entityId);
		meshRenderer.Material = assetId;
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

	[RegisterCall("ScriptGlue::Asset_GetIdentifier")]
	static void Asset_GetIdentifier(UUID assetId, out MonoString* text)
	{
		Asset asset = GetAssetOrThrow!<Asset>(assetId);

		text = Mono.mono_string_new_len(ScriptEngine.[Friend]s_AppDomain, asset.Identifier.Ptr, (uint32)asset.Identifier.Length);
	}

	[RegisterCall("ScriptGlue::Asset_SetIdentifier")]
	static void Asset_SetIdentifier(UUID assetId, MonoString* text)
	{
		ThrowNotImplementedException("Asset.GetIdentifier is not implemented.");

		/*AssetHandle handle = .(assetId);
		Asset asset = Content.GetAsset(handle, blocking: true);
		
		char8* rawText = Mono.mono_string_to_utf8(text);

		// TODO: I think it's not THAT easy.
		asset.Identifier = StringView(rawText);

		Mono.mono_free(rawText);*/
	}

#endregion

#region Material
	
	[RegisterCall("ScriptGlue::Material_SetVariable")]
	static void Material_SetVariable(AssetHandle assetHandle, MonoString* managedVariableName, ShaderVariableType elementType, int32 rows, int32 columns, int32 arrayLength, uint8* rawData, int32 dataLength)
	{
		Material material = GetAssetOrThrow!<Material>(assetHandle);

		char8* rawVariableName = Mono.mono_string_to_utf8(managedVariableName);

		material.[Friend]SetVariableRaw(StringView(rawVariableName), elementType, rows, columns , arrayLength, Span<uint8>(rawData, dataLength));

		Mono.mono_free(rawVariableName);
	}
	
	[RegisterCall("ScriptGlue::Material_ResetVariable")]
	static void Material_ResetVariable(AssetHandle assetHandle, MonoString* managedVariableName)
	{
		Material material = GetAssetOrThrow!<Material>(assetHandle);

		char8* rawVariableName = Mono.mono_string_to_utf8(managedVariableName);

		material.ResetVariable(StringView(rawVariableName));

		Mono.mono_free(rawVariableName);
	}

	[RegisterCall("ScriptGlue::Material_SetTexture")]
	static void Material_SetTexture(AssetHandle materialHandle, MonoString* managedVariableName, AssetHandle textureHandle)
	{
		Material material = GetAssetOrThrow!<Material>(materialHandle);

		char8* rawVariableName = Mono.mono_string_to_utf8(managedVariableName);

		material.SetTexture(StringView(rawVariableName), textureHandle);

		Mono.mono_free(rawVariableName);
	}

	[RegisterCall("ScriptGlue::Material_GetTexture")]
	static void Material_GetTexture(AssetHandle materialHandle, MonoString* managedVariableName, out AssetHandle textureHandle)
	{
		Material material = GetAssetOrThrow!<Material>(materialHandle);

		char8* rawVariableName = Mono.mono_string_to_utf8(managedVariableName);

		var v = material.GetTexture(StringView(rawVariableName), ?);

		if (v case .Err(let err))
		{
			ThrowInvalidOperationException(scope $"Error while getting texture from material {err}");
		}

		textureHandle = v.Value;

		Mono.mono_free(rawVariableName);
	}

	[RegisterCall("ScriptGlue::Material_ResetTexture")]
	static void Material_ResetTexture(AssetHandle materialHandle, MonoString* managedVariableName)
	{
		Material material = GetAssetOrThrow!<Material>(materialHandle);

		char8* rawVariableName = Mono.mono_string_to_utf8(managedVariableName);

		material.ResetTexture(StringView(rawVariableName));

		Mono.mono_free(rawVariableName);
	}

#endregion

#region ImGui Extension
	
	[RegisterCall("ScriptGlue::ImGuiExtension_ListElementGrabber")]
	static void ImGuiExtension_ListElementGrabber()
	{
		ImGui.ImGui.ListElementGrabber();
	}

#endregion

	public static void RegisterCall<T>(String name, T method) where T : var
	{
		Mono.mono_add_internal_call(scope $"GlitchyEngine.{name}", (void*)method);
	}
}
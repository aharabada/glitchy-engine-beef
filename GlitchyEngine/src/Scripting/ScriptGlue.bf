using Mono;
using System;
using GlitchLog;
using System.Reflection;
using GlitchyEngine.Events;
using GlitchyEngine.Math;
using GlitchyEngine.World;
using GlitchyEngine.Core;

namespace GlitchyEngine.Scripting;

static class ScriptGlue
{
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

	[RegisterMethod]
	private static void RegisterCalls()
	{
		// Generated at CompTime
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
	
	/*[RegisterCall("Input::IsMouseButtonReleasing")]
	static void Destroy()
	{
		// TODO:
	}*/

	[RegisterCall("ScriptGlue::Entity_GetTranslation")]
	static void Entity_GetTranslation(UUID entityId, ref Vector3 translation)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		translation = entity.Transform.Position;
	}
	
	[RegisterCall("ScriptGlue::Entity_SetTranslation")]
	static void Entity_SetTranslation(UUID entityId, ref Vector3 translation)
	{
		Scene scene = ScriptEngine.Context;
		Entity entity = scene.GetEntityByID(entityId);

		entity.Transform.Position = translation;
	}

#endregion

	private static void RegisterCall<T>(String name, T method) where T : var
	{
		Mono.mono_add_internal_call(scope $"GlitchyEngine.{name}", (void*)method);
	}
}
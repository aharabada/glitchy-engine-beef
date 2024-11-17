using System;
using System.Reflection;
using System.Collections;

namespace GlitchyEditor.Ultralight;

[AttributeUsage(.Method |.Field)]
struct BindToJsFunctionAttribute : Attribute
{
	public String FunctionName;

	public this(String functionName)
	{
		FunctionName = functionName;
	}
}

[AttributeUsage(.Method)]
struct BeefMethodBinderAttribute : Attribute, IOnMethodInit
{
	[Comptime]
	public void OnMethodInit(MethodInfo targetMethod, Self* prev)
	{
		HashSet<String> boundJsFunctions = new HashSet<String>();

		for (MethodInfo methodInfo in targetMethod.DeclaringType.GetMethods(.Instance | .Public | .NonPublic))
		{
			if (methodInfo.GetCustomAttribute<BindToJsFunctionAttribute>() case .Ok(let attribute))
			{
				Runtime.Assert(!boundJsFunctions.Contains(attribute.FunctionName), new $"The JS-Method {attribute.FunctionName} is already bound to another method.");

				boundJsFunctions.Add(attribute.FunctionName);

				String str = new $"BindMethodToJsFunction(context, scriptGlue, \"{attribute.FunctionName}\", new:stdAlloc => {methodInfo.Name});\n";
				Compiler.EmitMethodExit(targetMethod, str);
			}
		}

		for (FieldInfo fieldInfo in targetMethod.DeclaringType.GetFields(.Instance | .Public | .NonPublic))
		{
			if (fieldInfo.GetCustomAttribute<BindToJsFunctionAttribute>() case .Ok(let attribute))
			{
				// Runtime.Assert(t.IsDelegate, new $"The field must be of delegate type.");
				Runtime.Assert(!boundJsFunctions.Contains(attribute.FunctionName), new $"The JS-Method {attribute.FunctionName} is already bound to another method.");

				boundJsFunctions.Add(attribute.FunctionName);

				String str = new $"{fieldInfo.Name} = GetJsCallbackDelegate(context, scriptGlue, \"{attribute.FunctionName}\");\n";
				Compiler.EmitMethodExit(targetMethod, str);
			}
		}
	}
}

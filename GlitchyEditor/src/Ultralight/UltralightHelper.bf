using System;
using Ultralight.CAPI;
using GlitchyEngine;

namespace GlitchyEditor.Ultralight;

delegate void JSCallback(JSContextRef context, JSObjectRef thisObject, Span<JSValueRef> arguments, JSValueRef* exception = null);

static class UltralightHelper
{
	private static JSValueRef NativeFunctionCallback(JSContextRef ctx, JSObjectRef fn, JSObjectRef thisObject, uint32 argumentCount, JSValueRef* arguments, JSValueRef* exception)
	{
		JSCallback callback = (JSCallback)Internal.UnsafeCastToObject(JSObjectGetPrivate(fn));

		if (callback == null)
		{
			Log.EngineLogger.Error("The native callback of the function is null.");
			return JSValueMakeNull(ctx);
		}

		callback(ctx, thisObject, Span<JSValueRef>(arguments, argumentCount));
		
		return JSValueMakeNull(ctx);
	}

	private static void NativeFunctionFinalize(JSObjectRef object)
	{
		JSCallback callback = (JSCallback)Internal.UnsafeCastToObject(JSObjectGetPrivate(object));
		delete:(StdAllocator()) callback;
	}

	private static JSClassRef NativeFunctionClass()
	{
		static JSClassRef instance = null;
		if (instance == null)
		{
			JSClassDefinition def = .();
			def.className = "NativeFunction";
			def.attributes = (.)JSClassAttribute.kJSClassAttributeNone;
			def.callAsFunction = => NativeFunctionCallback;
			def.finalize = => NativeFunctionFinalize;
			instance = JSClassCreate(&def);
		}

		return instance;
	}

	public static JSObjectRef CreateJsFunctionFromDelegate(JSContextRef context, JSCallback ownCallback)
	{
		return JSObjectMake(context, NativeFunctionClass(), Internal.UnsafeCastToPtr(ownCallback));
	}
}

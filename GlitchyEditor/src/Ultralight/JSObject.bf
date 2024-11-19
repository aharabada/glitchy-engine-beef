using Ultralight.CAPI;
using System;
namespace GlitchyEditor.Ultralight;

class JSObject
{
	private JSContextRef _jsContext;
	private JSObjectRef _jsObject;
	
	public JSObjectRef ObjectRef => _jsObject;

	private this(JSContextRef context)
	{
		_jsContext = context;
	}

	public static JSObject CreateArray(JSContextRef context)
	{
		JSObject object = new JSObject(context);
		
		object._jsObject = JSObjectMakeArray(context, 0, null, null);

		return object;
	}

	public JSObjectRef this[int index]
	{
		get => JSObjectGetPropertyAtIndex(_jsContext, _jsObject, (uint32)index, null);
		set => JSObjectSetPropertyAtIndex(_jsContext, _jsObject, (uint32)index, value, null);
	}
}

class JSString
{
	private JSContextRef _context;
	private JSStringRef _string;

	public this(JSContextRef context, JSValueRef jsValue)
	{
		_context = context;
		_string = JSValueToStringCopy(context, jsValue, null);
	}

	public ~this()
	{
		//JSStringRelease(_string);
	}

	public void GetUTF8String(String buffer)
	{
		buffer.Append(Span<char16>((char16*)JSStringGetCharactersPtr(_string), JSStringGetLength(_string)));
	}
}

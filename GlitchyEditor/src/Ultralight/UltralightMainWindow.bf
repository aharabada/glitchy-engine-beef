using Ultralight.CAPI;

namespace GlitchyEditor.Ultralight;

class UltralightMainWindow : UltralightWindow
{
	public this() : base("Glitchy Engine", "file:///dist/index.html") // "file:///react-ui-prototype/dist/index.html"
	//public this() : base("Entity Hierarchy", "file:///another-react-test/index.html")
	{

	}
	
	///
	/// This callback is bound to a JavaScript function on the page.
	///
	static JSValueRef GetMessage(JSContextRef ctx, JSObjectRef fn, JSObjectRef thisObject, uint32 argumentCount, JSValueRef* arguments, JSValueRef* exception) {
		///
		/// Create a JavaScript String from a C-string, initialize it with our
		/// welcome message.
		///
		JSStringRef str = JSStringCreateWithUTF8CString("Hello from Beef!");
		
		///
		/// Create a garbage-collected JSValue using the String we just created.
		///
		///  **Note**:
		///    Both JSValueRef and JSObjectRef types are garbage-collected types. (And actually,
		///    JSObjectRef is just a typedef of JSValueRef, they share definitions).
		///
		///    The garbage collector in JavaScriptCore periodically scans the entire stack to check if
		///    there are any active JSValueRefs, and marks those with no references for destruction.
		///
		///    If you happen to store a JSValueRef/JSObjectRef in heap memory or in memory unreachable
		///    by the stack-based garbage-collector, you should explicitly call JSValueProtect() and
		///    JSValueUnprotect() on the reference to ensure it is kept alive.
		///
		JSValueRef value = JSValueMakeString(ctx, str);
		
		///
		/// Release the string we created earlier (we only Release what we Create).
		///
		JSStringRelease(str);
		
		return value;
	}

	protected override void OnDOMReady(C_View* caller, uint64 frame_id, bool is_main_frame, C_String* url)
	{
		///
		/// Acquire the page's JavaScript execution context.
		///
		/// This locks the JavaScript context so we can modify it safely on this thread, we need to
		/// unlock it when we're done via ulViewUnlockJSContext().
		///
		JSContextRef ctx = ulViewLockJSContext(_view);

		///
		/// Create a JavaScript String containing the name of our callback.
		///
		JSStringRef name = JSStringCreateWithUTF8CString("OnCreateEntityClick");

		///
		/// Create a garbage-collected JavaScript function that is bound to our native C callback 
		/// 'GetMessage()'.
		///
		JSObjectRef func = JSObjectMakeFunctionWithCallback(ctx, name, => GetMessage);

		///
		/// Store our function in the page's global JavaScript object so that it is accessible from the
		/// page as 'GetMessage()'.
		///
		/// The global JavaScript object is also known as 'window' in JS.
		///
		JSObjectSetProperty(ctx, JSContextGetGlobalObject(ctx), name, func, 0, null);

		///
		/// Release the JavaScript String we created earlier.
		///
		JSStringRelease(name);

		///
		/// Unlock the JS context so other threads can modify JavaScript state.
		///
		ulViewUnlockJSContext(_view);
	}
}

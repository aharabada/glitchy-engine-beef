#if BF_PLATFORM_WINDOWS

using System;
using System.Threading;
using DirectX.Common;
using GlitchyEngine;

namespace GlitchyEditor.Platform.Windows.Com;

/// Owns an IDispatch pointer and provides late bound access to its properties and methods
/// (GetIDsOfNames + Invoke). Calls that are rejected because the COM server is busy
/// (e.g. Visual Studio showing a modal dialog or building) are retried for a bounded time.
class ComDispatch
{
	private const int MaxBusyRetries = 20;
	private const int BusyRetrySleepMs = 150;

	private static Guid sIID_NULL = .();

	private IDispatch* _dispatch;

	/// Takes ownership of the reference held by dispatch.
	public this(IDispatch* dispatch)
	{
		_dispatch = dispatch;
	}

	public ~this()
	{
		if (_dispatch != null)
			_dispatch.Release();
	}

	/// The caller must release the returned VARIANT with VariantClear.
	public Result<VARIANT> GetProperty(StringView name)
	{
		return InvokeInternal(name, .PropertyGet, default);
	}

	/// Arguments are passed in natural (declaration) order and are released by this method.
	/// The caller must release the returned VARIANT with VariantClear.
	public Result<VARIANT> InvokeMethod(StringView name, Span<VARIANT> args = default)
	{
		Result<VARIANT> result = InvokeInternal(name, .Method, args);

		for (int i < args.Length)
			VariantClear(&args[i]);

		return result;
	}

	/// Returns the property value as a new ComDispatch (fails if the property is not an object or null).
	public Result<ComDispatch> GetObjectProperty(StringView name)
	{
		VARIANT value = Try!(GetProperty(name));

		if (value.vt == .Dispatch && value.pdispVal != null)
		{
			// The new ComDispatch takes over the reference held by the VARIANT, so no VariantClear here.
			return new ComDispatch(value.pdispVal);
		}

		VariantClear(&value);
		return .Err;
	}

	/// Appends the string property value to outValue.
	public Result<void> GetStringProperty(StringView name, String outValue)
	{
		VARIANT value = Try!(GetProperty(name));
		defer VariantClear(&value);

		if (value.vt != .Bstr || value.bstrVal == null)
			return .Err;

		outValue.Append(value.bstrVal);
		return .Ok;
	}

	private Result<VARIANT> InvokeInternal(StringView name, DispatchFlags flags, Span<VARIANT> args)
	{
		char16* nameW = name.ToScopedNativeWChar!();

		int32 dispId = 0;
		HResult result = _dispatch.GetIDsOfNames(&sIID_NULL, &nameW, 1, LOCALE_USER_DEFAULT, &dispId);

		if (result.Failed)
		{
			Log.EngineLogger.Error(scope $"IDispatch.GetIDsOfNames failed for \"{name}\": {result} ({(uint32)result:X8})");
			return .Err;
		}

		// IDispatch expects the arguments in reverse order (rgvarg[0] is the last parameter).
		VARIANT[] reversedArgs = scope VARIANT[args.Length];

		for (int i < args.Length)
			reversedArgs[i] = args[args.Length - 1 - i];

		DISPPARAMS dispParams = .()
		{
			rgvarg = reversedArgs.Ptr,
			rgdispidNamedArgs = null,
			cArgs = (uint32)args.Length,
			cNamedArgs = 0
		};

		VARIANT returnValue = default;
		EXCEPINFO excepInfo = default;

		for (int attempt = 0; true; attempt++)
		{
			result = _dispatch.Invoke(dispId, &sIID_NULL, LOCALE_USER_DEFAULT, flags, &dispParams, &returnValue, &excepInfo, null);

			if ((result == .RPC_E_CALL_REJECTED || result == .RPC_E_SERVERCALL_RETRYLATER) && attempt < MaxBusyRetries)
			{
				Thread.Sleep(BusyRetrySleepMs);
				continue;
			}

			break;
		}

		if (result == .DISP_E_EXCEPTION)
		{
			if (excepInfo.bstrDescription == null && excepInfo.pfnDeferredFillIn != null)
				excepInfo.pfnDeferredFillIn(&excepInfo);

			String description = scope .();

			if (excepInfo.bstrDescription != null)
				description.Append(excepInfo.bstrDescription);

			Log.EngineLogger.Error(scope $"IDispatch.Invoke of \"{name}\" threw an exception: \"{description}\" (scode: {(uint32)excepInfo.scode:X8})");

			excepInfo.FreeStrings();

			return .Err;
		}

		if (result.Failed)
		{
			Log.EngineLogger.Error(scope $"IDispatch.Invoke of \"{name}\" failed: {result} ({(uint32)result:X8})");
			return .Err;
		}

		return returnValue;
	}
}

#endif

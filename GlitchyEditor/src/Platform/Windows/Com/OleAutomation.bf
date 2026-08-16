#if BF_PLATFORM_WINDOWS

using System;
using DirectX.Common;

namespace GlitchyEditor.Platform.Windows.Com;

typealias BSTR = char16*;

static
{
	public const uint32 COINIT_APARTMENTTHREADED = 0x2;
	public const uint32 LOCALE_USER_DEFAULT = 0x0400;

	public const int32 SW_RESTORE = 9;

	[Import("Ole32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern HResult CoInitializeEx(void* reserved, uint32 coInit);
	[Import("Ole32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern void CoUninitialize();
	[Import("Ole32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern void CoTaskMemFree(void* pointer);

	[Import("OleAut32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern BSTR SysAllocString(char16* str);
	[Import("OleAut32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern void SysFreeString(BSTR str);
	[Import("OleAut32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern uint32 SysStringLen(BSTR str);
	[Import("OleAut32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern HResult VariantClear(VARIANT* variant);

	[Import("user32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern System.Windows.IntBool SetForegroundWindow(int hwnd);
	[Import("user32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern System.Windows.IntBool IsIconic(int hwnd);
	[Import("user32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern System.Windows.IntBool ShowWindow(int hwnd, int32 cmdShow);
}

public enum VarType : uint16
{
	Empty = 0,
	I2 = 2,
	I4 = 3,
	Bstr = 8,
	Dispatch = 9,
	Bool = 11,
	Unknown = 13,
	UI4 = 19,
	I8 = 20
}

public enum DispatchFlags : uint16
{
	Method = 0x1,
	PropertyGet = 0x2,
	PropertyPut = 0x4,
	PropertyPutRef = 0x8
}

[CRepr]
public struct VARIANT
{
	public const int16 VARIANT_TRUE = -1;
	public const int16 VARIANT_FALSE = 0;

	public VarType vt;
	public uint16 wReserved1;
	public uint16 wReserved2;
	public uint16 wReserved3;
	public using _Value Value;

	[CRepr, Union]
	public struct _Value
	{
		public int64 llVal;
		public int32 lVal;
		public int16 iVal;
		public int16 boolVal;
		public BSTR bstrVal;
		public IDispatch* pdispVal;
		public IUnknown* punkVal;
		// BRECORD is the widest union member and forces the correct union size of 16 bytes.
		public _Record brecord;

		[CRepr]
		public struct _Record
		{
			public void* pvRecord;
			public void* pRecInfo;
		}
	}

	/// The returned VARIANT owns the BSTR; release it with VariantClear.
	public static VARIANT FromBStr(StringView value)
	{
		VARIANT variant = default;
		variant.vt = .Bstr;
		variant.bstrVal = SysAllocString(value.ToScopedNativeWChar!());
		return variant;
	}

	public static VARIANT FromInt32(int32 value)
	{
		VARIANT variant = default;
		variant.vt = .I4;
		variant.lVal = value;
		return variant;
	}

	public static VARIANT FromBool(bool value)
	{
		VARIANT variant = default;
		variant.vt = .Bool;
		variant.boolVal = value ? VARIANT_TRUE : VARIANT_FALSE;
		return variant;
	}

	/// Extracts a window handle. VS is a 64 bit process but EnvDTE declares HWnd as a 32 bit int,
	/// so depending on the marshalling we might see I4, UI4 or I8 (HWND values are 32 bit significant).
	public Result<int> GetHwnd()
	{
		switch (vt)
		{
		case .I4:
			return (int)lVal;
		case .UI4:
			return (int)(uint32)lVal;
		case .I8:
			return (int)llVal;
		default:
			return .Err;
		}
	}
}

[CRepr]
public struct DISPPARAMS
{
	public VARIANT* rgvarg;
	public int32* rgdispidNamedArgs;
	public uint32 cArgs;
	public uint32 cNamedArgs;
}

[CRepr]
public struct EXCEPINFO
{
	public uint16 wCode;
	public uint16 wReserved;
	public BSTR bstrSource;
	public BSTR bstrDescription;
	public BSTR bstrHelpFile;
	public uint32 dwHelpContext;
	public void* pvReserved;
	public function [CallingConvention(.Stdcall)] HResult(EXCEPINFO* excepInfo) pfnDeferredFillIn;
	public int32 scode;

	public void FreeStrings() mut
	{
		if (bstrSource != null)
			SysFreeString(bstrSource);
		if (bstrDescription != null)
			SysFreeString(bstrDescription);
		if (bstrHelpFile != null)
			SysFreeString(bstrHelpFile);

		bstrSource = null;
		bstrDescription = null;
		bstrHelpFile = null;
	}
}

[CRepr]
public struct IDispatch : IUnknown
{
	public const new Guid IID = .(0x00020400, 0x0000, 0x0000, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46);

	public new VTable* VT { get => (.)mVT; }

	public HResult GetIDsOfNames(Guid* riid, char16** names, uint32 nameCount, uint32 localeId, int32* dispIds) mut =>
		VT.GetIDsOfNames(&this, riid, names, nameCount, localeId, dispIds);
	public HResult Invoke(int32 dispIdMember, Guid* riid, uint32 localeId, DispatchFlags flags, DISPPARAMS* dispParams, VARIANT* result, EXCEPINFO* excepInfo, uint32* argErr) mut =>
		VT.Invoke(&this, dispIdMember, riid, localeId, flags, dispParams, result, excepInfo, argErr);

	[CRepr]
	public struct VTable : IUnknown.VTable
	{
		// Slots we don't use, kept as placeholders so the layout stays correct.
		public void* GetTypeInfoCount;
		public void* GetTypeInfo;
		public function [CallingConvention(.Stdcall)] HResult(IDispatch* self, Guid* riid, char16** names, uint32 nameCount, uint32 localeId, int32* dispIds) GetIDsOfNames;
		public function [CallingConvention(.Stdcall)] HResult(IDispatch* self, int32 dispIdMember, Guid* riid, uint32 localeId, DispatchFlags flags, DISPPARAMS* dispParams, VARIANT* result, EXCEPINFO* excepInfo, uint32* argErr) Invoke;
	}
}

namespace DirectX.Common
{
	extension HResult
	{
		/// The COM server rejected the call (e.g. Visual Studio is busy). Retry later.
		public const HResult RPC_E_CALL_REJECTED = (.)0x80010001;
		/// The COM server asked us to retry the call later.
		public const HResult RPC_E_SERVERCALL_RETRYLATER = (.)0x8001010A;
		/// IDispatch::Invoke failed with an exception, details are in the EXCEPINFO.
		public const HResult DISP_E_EXCEPTION = (.)0x80020009;
	}
}

#endif

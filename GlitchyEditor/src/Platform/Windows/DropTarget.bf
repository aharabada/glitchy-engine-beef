using System;
using DirectX.Common;
using DirectX.Math;
using GlitchyEngine;
using GlitchyEngine.Events;
using static System.Windows;
using GlitchyEngine.Math;
using System.Collections;
using System.IO;

namespace GlitchyEditor.Platform.Windows;

// This entire thing is so platform dependent, that it really doesn't make sense to abstract while we are windows only.

static
{
	[Import("Ole32.lib"), CLink]
	public static extern HResult OleInitialize(void* reserved);
	[Import("Ole32.lib"), CLink]
	public static extern void OleUninitialize();
	[Import("Ole32.lib"), CLink]
	public static extern HResult RegisterDragDrop(HWnd windowHandle, IDropTarget* dropTarget);
	[Import("Ole32.lib"), CLink]
	public static extern HResult RevokeDragDrop(HWnd windowHandle);
}

[CRepr]
struct IDropTarget : IUnknown
{
	public static new Guid IID => .("00000122-0000-0000-C000-000000000046");
	
	[CRepr]
	public struct VTable : IUnknown.VTable
	{
		public function [CallingConvention(.Stdcall)] HResult(IDropTarget* self, /*IDataObject*/ IUnknown* dataObject, uint32 grfKeyState, int2 point, ref DropEffect effect) DragEnter;
		public function [CallingConvention(.Stdcall)] HResult(IDropTarget* self, uint32 grfKeyState, int2 point, ref DropEffect effect) DragOver;
		public function [CallingConvention(.Stdcall)] HResult(IDropTarget* self) DragLeave;
		public function [CallingConvention(.Stdcall)] HResult(IDropTarget* self, IDataObject* dataObject, uint32 grfKeyState, int2 point, ref DropEffect effect) Drop;
	}

	public new VTable* VT => (VTable*)mVT;

	public HResult DragEnter(/*IDataObject*/ IUnknown* dataObject, uint32 grfKeyState, int2 point, ref DropEffect effect) mut
	{
		return VT.DragEnter(&this, dataObject, grfKeyState, point, ref effect);
	}

	public HResult DragOver(uint32 grfKeyState, int2 point, ref DropEffect effect) mut
	{
		return VT.DragOver(&this, grfKeyState, point, ref effect);
	}

	public HResult DragLeave() mut
	{
		return VT.DragLeave(&this);
	}
	
	public HResult Drop(IDataObject* dataObject, uint32 grfKeyState, int2 point, ref DropEffect effect) mut
	{
		return VT.Drop(&this, dataObject, grfKeyState, point, ref effect);
	}
}
[CRepr]
public struct DVTARGETDEVICE
{
	public uint32 tdSize;
	public uint16 tdDriverNameOffset;
	public uint16 tdDeviceNameOffset;
	public uint16 tdPortNameOffset;
	public uint16 tdExtDevmodeOffset;
	public uint8[1] tdData_array;
	
	public uint8* tdData mut => &tdData_array[0];
}
[CRepr]
public struct FORMATETC
{
	public uint16 cfFormat;
	public DVTARGETDEVICE* ptd;
	public uint32 dwAspect;
	public int32 lindex;
	public uint32 tymed;
}
	public typealias HDROP = int;
	public typealias HBITMAP = int;
	public typealias HENHMETAFILE = int;
	public typealias PWSTR = char16*;
	public typealias BOOL = int32;
[CRepr]
public struct STGMEDIUM
{
	public uint32 tymed;
	public using _Anonymous_e__Union Anonymous;
	public IUnknown* pUnkForRelease;
	
	[CRepr, Union]
	public struct _Anonymous_e__Union
	{
		public HBITMAP hBitmap;
		public void* hMetaFilePict;
		public HENHMETAFILE hEnhMetaFile;
		public int hGlobal;
		public PWSTR lpszFileName;
		public /*IStream*/IUnknown* pstm;
		public /*IStorage*/IUnknown* pstg;
	}
}
[CRepr]
public struct IDataObject : IUnknown
{
	public const new Guid IID = .(0x0000010e, 0x0000, 0x0000, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46);
	
	public new VTable* VT { get => (.)mVT; }
	
	public HResult GetData(ref FORMATETC pformatetcIn, out STGMEDIUM pmedium) mut => VT.GetData(ref this, ref pformatetcIn, out pmedium);
	public HResult GetDataHere(ref FORMATETC pformatetc, out STGMEDIUM pmedium) mut => VT.GetDataHere(ref this, ref pformatetc, out pmedium);
	public HResult QueryGetData(ref FORMATETC pformatetc) mut => VT.QueryGetData(ref this, ref pformatetc);
	public HResult GetCanonicalFormatEtc(ref FORMATETC pformatectIn, out FORMATETC pformatetcOut) mut => VT.GetCanonicalFormatEtc(ref this, ref pformatectIn, out pformatetcOut);
	public HResult SetData(ref FORMATETC pformatetc, ref STGMEDIUM pmedium, BOOL fRelease) mut => VT.SetData(ref this, ref pformatetc, ref pmedium, fRelease);
	public HResult EnumFormatEtc(uint32 dwDirection, out /*IEnumFORMATETC*/ IUnknown* ppenumFormatEtc) mut => VT.EnumFormatEtc(ref this, dwDirection, out ppenumFormatEtc);
	public HResult DAdvise(ref FORMATETC pformatetc, uint32 advf, ref /*IAdviseSink*/ IUnknown* pAdvSink, out uint32 pdwConnection) mut => VT.DAdvise(ref this, ref pformatetc, advf, ref pAdvSink, out pdwConnection);
	public HResult DUnadvise(uint32 dwConnection) mut => VT.DUnadvise(ref this, dwConnection);
	public HResult EnumDAdvise(out /*IEnumSTATDATA*/ IUnknown* ppenumAdvise) mut => VT.EnumDAdvise(ref this, out ppenumAdvise);

	[CRepr]
	public struct VTable : IUnknown.VTable
	{
		public new function [CallingConvention(.Stdcall)] HResult(ref IDataObject self, ref FORMATETC pformatetcIn, out STGMEDIUM pmedium) GetData;
		public new function [CallingConvention(.Stdcall)] HResult(ref IDataObject self, ref FORMATETC pformatetc, out STGMEDIUM pmedium) GetDataHere;
		public new function [CallingConvention(.Stdcall)] HResult(ref IDataObject self, ref FORMATETC pformatetc) QueryGetData;
		public new function [CallingConvention(.Stdcall)] HResult(ref IDataObject self, ref FORMATETC pformatectIn, out FORMATETC pformatetcOut) GetCanonicalFormatEtc;
		public new function [CallingConvention(.Stdcall)] HResult(ref IDataObject self, ref FORMATETC pformatetc, ref STGMEDIUM pmedium, BOOL fRelease) SetData;
		public new function [CallingConvention(.Stdcall)] HResult(ref IDataObject self, uint32 dwDirection, out /*IEnumFORMATETC*/ IUnknown* ppenumFormatEtc) EnumFormatEtc;
		public new function [CallingConvention(.Stdcall)] HResult(ref IDataObject self, ref FORMATETC pformatetc, uint32 advf, ref /*IAdviseSink*/ IUnknown* pAdvSink, out uint32 pdwConnection) DAdvise;
		public new function [CallingConvention(.Stdcall)] HResult(ref IDataObject self, uint32 dwConnection) DUnadvise;
		public new function [CallingConvention(.Stdcall)] HResult(ref IDataObject self, out /*IEnumSTATDATA*/ IUnknown* ppenumAdvise) EnumDAdvise;
	}
}

[CRepr]
enum DropEffect
{
	None = 0,
	Copy = 1,
	Move = 2,
	Link = 4,
	Scroll = 0x80000000,
}

public enum CLIPBOARD_FORMATS : uint32
{
	TEXT = 1,
	BITMAP = 2,
	METAFILEPICT = 3,
	SYLK = 4,
	DIF = 5,
	TIFF = 6,
	OEMTEXT = 7,
	DIB = 8,
	PALETTE = 9,
	PENDATA = 10,
	RIFF = 11,
	WAVE = 12,
	UNICODETEXT = 13,
	ENHMETAFILE = 14,
	HDROP = 15,
	LOCALE = 16,
	DIBV5 = 17,
	MAX = 18,
	OWNERDISPLAY = 128,
	DSPTEXT = 129,
	DSPBITMAP = 130,
	DSPMETAFILEPICT = 131,
	DSPENHMETAFILE = 142,
	PRIVATEFIRST = 512,
	PRIVATELAST = 767,
	GDIOBJFIRST = 768,
	GDIOBJLAST = 1023,
}

public enum TYMED : int32
{
	HGLOBAL = 1,
	FILE = 2,
	ISTREAM = 4,
	ISTORAGE = 8,
	GDI = 16,
	MFPICT = 32,
	ENHMF = 64,
	NULL = 0,
}

abstract class IDropTargetImplBase : RefCounted
{
	[CRepr]
	private struct IDropTargetImpl : IDropTarget
	{
		public void* ClassPtr;
	}

	IDropTargetImpl impl;

	IDropTarget.VTable vTable;

	public this()
	{
		impl = .();
		impl.[Friend]mVT = &vTable;
		impl.ClassPtr = Internal.UnsafeCastToPtr(this);
		
		vTable.QueryInterface = => QueryInterfaceImpl;
		vTable.AddRef = => AddRefImpl;
		vTable.Release = => ReleaseImpl;

		vTable.DragEnter = => DragEnterImpl;
		vTable.DragOver = => DragOverImpl;
		vTable.DragLeave = => DragLeaveImpl;
		vTable.Drop = => DropImpl;
	}

	public void Register()
	{
		HResult result = RegisterDragDrop(Application.Instance.Window.[Friend]_windowHandle, &impl);
		Log.EngineLogger.Assert(result not case .E_OUTOFMEMORY, "Failed to register drag drop handler (E_OUTOFMEMORY). Make sure you called OleInitialize and not CoInitialize[Ex]");
		Log.EngineLogger.Assert(result case .S_OK);
	}

	public void Unregister()
	{
		HResult result = RevokeDragDrop(Application.Instance.Window.[Friend]_windowHandle);
		Log.EngineLogger.Assert(result case .S_OK);
	}

	private static IDropTargetImplBase GetInstance(IUnknown* self)
	{
		IDropTargetImpl* impl = (.)self;

		return (.)Internal.UnsafeCastToObject(impl.ClassPtr);
	}

	private static HResult QueryInterfaceImpl(IUnknown* self, ref Guid riid, void** output)
	{
		Self instance = GetInstance(self);

		HResult result = .E_NOINTERFACE;
		*output = null;

		if (riid == IUnknown.IID || riid == IDropTarget.IID) 
		{
			*output = (IUnknown*)&instance.impl;
			instance.AddRef();
			result = .S_OK;
		}

		return result;
	}

	private static uint32 AddRefImpl(IUnknown* self)
	{
		Self instance = GetInstance(self);

		instance.AddRef();
		return (uint32)instance.RefCount;
	}

	private static uint32 ReleaseImpl(IUnknown* self)
	{
		Self instance = GetInstance(self);

		uint32 count = (uint32)instance.ReleaseRefNoDelete();

		if (count == 0)
			delete instance;

		return count;
	}

	// TODO: Data object? KeyState? 
	public abstract Result<DropEffect> OnDragEnter(int2 cursorPosition);
	public abstract Result<DropEffect> OnDragOver(int2 cursorPosition);
	public abstract Result<void> OnDragLeave();
	public abstract Result<DropEffect> OnDrop(int2 cursorPosition, List<String> fileNames);

	[CallingConvention(.Stdcall)]
	private static HResult DragEnterImpl(IDropTarget* self, /*IDataObject*/ IUnknown* dataObject, uint32 grfKeyState, int2 point, ref DropEffect effect)
	{
		Self instance = GetInstance(self);

		Result<DropEffect> result = instance.OnDragEnter(point);

		if (result case .Ok(out effect))
			return .S_OK;

		return .E_FAIL;
	}
	
	[CallingConvention(.Stdcall)]
	private static HResult DragOverImpl(IDropTarget* self, uint32 grfKeyState, int2 point, ref DropEffect effect)
	{
		Self instance = GetInstance(self);
		Result<DropEffect> result = instance.OnDragOver(point);

		if (result case .Ok(out effect))
			return .S_OK;

		return .E_FAIL;
	}
	
	[CallingConvention(.Stdcall)]
	private static HResult DragLeaveImpl(IDropTarget* self)
	{
		Self instance = GetInstance(self);
		Result<void> result = instance.OnDragLeave();

		if (result case .Ok)
			return .S_OK;

		return .E_FAIL;
	}

	[Import("shell32.dll"), CLink, CallingConvention(.Stdcall)]
	public static extern uint32 DragQueryFileW(HDROP hDrop, uint32 iFile, char16* lpszFile, uint32 cch);

	[Import("ole32.dll"), CLink, CallingConvention(.Stdcall)]
	public static extern void ReleaseStgMedium(ref STGMEDIUM param0);

	[CallingConvention(.Stdcall)]
	private static HResult DropImpl(IDropTarget* self, IDataObject* dataObject, uint32 grfKeyState, int2 point, ref DropEffect effect)
	{
		Self instance = GetInstance(self);

		// render the data into stgm using the data description in fmte
		FORMATETC format = .()
		{
			cfFormat = (.)CLIPBOARD_FORMATS.HDROP,
			ptd = null,
			lindex = -1,
			tymed = (.)TYMED.HGLOBAL
		};

		List<String> files = null;
		defer {DeleteContainerAndItems!(files);}

		if (dataObject.GetData(ref format, var stgm).Succeeded)
		{
			HDROP hdrop = (HDROP)stgm.hGlobal;
			uint32 fileCount = DragQueryFileW(hdrop, 0xFFFFFFFF, null, 0);

			files = new List<String>(fileCount);

			List<char16> buffer = scope List<char16>();
			buffer.Resize(256);

			for (uint32 i < fileCount)
			{
				uint32 requiredSize = DragQueryFileW(hdrop, i, null, 0);
				buffer.Resize(requiredSize + 1);

				uint32 retrievedSize = DragQueryFileW(hdrop, i, buffer.Ptr, (.)buffer.Count);
				if (retrievedSize > 0 && retrievedSize < buffer.Count)
				{
					String str = new String(buffer.Ptr);
					files.Add(str);
				}
			}

			ReleaseStgMedium(ref stgm);
		}

		Result<DropEffect> result = instance.OnDrop(point, files);

		if (result case .Ok(out effect))
			return .S_OK;

		return .E_FAIL;
	}
}

struct S
{
	bool b1;
	int32 i32;
	bool b2;
	int64 i64;
	int32 i322;
}

struct SB
{
	int64 i64;
	int32 i32;
	int32 i322;
	bool b1;
	bool b2;
}

struct SC
{
	bool b1;
	//filler 56
	int32 i32;
	//filler 32
	bool b2;
	//filler 56
	int64 i64;
	int32 i322;
	//filler 32
}

public enum DragDropType
{
	Enter,
	Over,
	Leave,
	Drop
}

public class DragDropEvent : Event, IEvent
{
	public override EventType EventType => .DragDropEvent;

	public override StringView Name => "DragDropEvent";

	public override EventCategory Category => .Application;

	public static EventType StaticType => .DragDropEvent;

	public DragDropType DragDropType { get; private set; }
	public int2 CursorPosition { get; private set; }

	public DropEffect OutDropEffect { get; set; }

	// Do not keep references to this list or any of it's items outside of the event handler, they will not survive it.
	public List<String> FileNames { get; set; }

	// TODO: Keys, or perhaps just make the listeners query them...

	public this(DragDropType dragDropType, int2 cursorPosition)
	{
		DragDropType = dragDropType;
		CursorPosition = cursorPosition;
	}
}

namespace GlitchyEngine.Events
{
	public extension EventType
	{
		case DragDropEvent;
	}
}

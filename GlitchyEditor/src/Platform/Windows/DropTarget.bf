#if BF_PLATFORM_WINDOWS

using System;
using DirectX.Common;
using DirectX.Math;
using GlitchyEngine;
using GlitchyEngine.Events;
using static System.Windows;
using GlitchyEngine.Math;
using System.Collections;
using System.IO;
using GlitchyEngine.Platform.Windows.Com;

namespace GlitchyEditor.Platform.Windows;

static
{
	[Import("Ole32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern HResult OleInitialize(void* reserved);
	[Import("Ole32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern void OleUninitialize();
	[Import("Ole32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern HResult RegisterDragDrop(HWnd windowHandle, IDropTarget* dropTarget);
	[Import("Ole32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern HResult RevokeDragDrop(HWnd windowHandle);
	[Import("ole32.dll"), CLink, CallingConvention(.Stdcall)]
	public static extern HResult DoDragDrop(IDataObject* pDataObj, IDropSource* pDropSource, DropEffect dwOKEffects, out DropEffect pdwEffect);
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
		public Handle hGlobal;
		public PWSTR lpszFileName;
		public /*IStream*/IUnknown* pstm;
		public /*IStorage*/IUnknown* pstg;
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

abstract class IDropTargetImplBase : IUnknownImplBase<IDropTarget, IDropTarget.VTable>
{
	protected override void InitVTable(ref IDropTarget.VTable vTable)
	{
		vTable.DragEnter = => DragEnterImpl;
		vTable.DragOver = => DragOverImpl;
		vTable.DragLeave = => DragLeaveImpl;
		vTable.Drop = => DropImpl;
	}

	public void Register()
	{
		HResult result = RegisterDragDrop(Application.Instance.Window.[Friend]_windowHandle, InterfacePtr);
		Log.EngineLogger.Assert(result not case .E_OUTOFMEMORY, "Failed to register drag drop handler (E_OUTOFMEMORY). Make sure you called OleInitialize and not CoInitialize[Ex]");
		Log.EngineLogger.Assert(result case .S_OK);
	}

	public void Unregister()
	{
		HResult result = RevokeDragDrop(Application.Instance.Window.[Friend]_windowHandle);
		Log.EngineLogger.Assert(result case .S_OK);

		OleUninitialize();
	}

	// TODO: Data object? KeyState? 
	public abstract Result<DropEffect> OnDragEnter(int2 cursorPosition);
	public abstract Result<DropEffect> OnDragOver(int2 cursorPosition);
	public abstract Result<void> OnDragLeave();
	public abstract Result<DropEffect> OnDrop(int2 cursorPosition, Span<StringView> fileNames);

	[CallingConvention(.Stdcall)]
	private static HResult DragEnterImpl(IDropTarget* self, /*IDataObject*/ IUnknown* dataObject, uint32 grfKeyState, int2 point, ref DropEffect effect)
	{
		Self instance = GetInstance<Self>(self);

		Result<DropEffect> result = instance.OnDragEnter(point);

		if (result case .Ok(out effect))
			return .S_OK;

		return .E_FAIL;
	}
	
	[CallingConvention(.Stdcall)]
	private static HResult DragOverImpl(IDropTarget* self, uint32 grfKeyState, int2 point, ref DropEffect effect)
	{
		Self instance = GetInstance<Self>(self);
		Result<DropEffect> result = instance.OnDragOver(point);

		if (result case .Ok(out effect))
			return .S_OK;

		return .E_FAIL;
	}
	
	[CallingConvention(.Stdcall)]
	private static HResult DragLeaveImpl(IDropTarget* self)
	{
		Self instance = GetInstance<Self>(self);
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
		Self instance = GetInstance<Self>(self);

		// render the data into stgm using the data description in fmte
		FORMATETC format = .()
		{
			cfFormat = (.)CLIPBOARD_FORMATS.HDROP,
			ptd = null,
			lindex = -1,
			tymed = (.)TYMED.HGLOBAL
		};

		String paths = scope .();
		List<StringView> files = null;
		defer { delete files; }

		if (dataObject.GetData(ref format, var stgm).Succeeded)
		{
			HDROP hdrop = (HDROP)stgm.hGlobal;
			uint32 fileCount = DragQueryFileW(hdrop, 0xFFFFFFFF, null, 0);

			files = new List<StringView>(fileCount);

			List<char16> buffer = scope List<char16>();
			buffer.Resize(256);

			for (uint32 i < fileCount)
			{
				uint32 requiredSize = DragQueryFileW(hdrop, i, null, 0);
				buffer.Resize(requiredSize + 1);

				uint32 retrievedSize = DragQueryFileW(hdrop, i, buffer.Ptr, (.)buffer.Count);
				if (retrievedSize > 0 && retrievedSize < buffer.Count)
				{
					int startIndex = paths.Length;
					paths.Append(buffer);
					int endIndex = paths.Length;

					// StringViews might be invalid until fixup step down below
					files.Add(StringView(paths, startIndex, endIndex - startIndex - 1));
				}
			}

			ReleaseStgMedium(ref stgm);
		}

		int index = 0;

		// Fixup pointer of string views
		for (ref StringView path in ref files)
		{
			path.Ptr = paths.Ptr + index;
			index += path.Length + 1;
		}

		Result<DropEffect> result = instance.OnDrop(point, files);

		if (result case .Ok(out effect))
			return .S_OK;

		return .E_FAIL;
	}
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

	/// Do not keep references to this list or any of it's items outside of the event handler, they will not survive it.
	public Span<StringView> FileNames { get; set; }

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

#endif

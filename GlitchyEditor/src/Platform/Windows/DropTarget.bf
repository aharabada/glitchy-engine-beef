using System;
using DirectX.Common;
using DirectX.Math;
using GlitchyEngine;
using GlitchyEngine.Events;
using static System.Windows;
using GlitchyEngine.Math;

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
		public function [CallingConvention(.Stdcall)] HResult(IDropTarget* self, /*IDataObject*/ IUnknown* dataObject, uint32 grfKeyState, int2 point, ref DropEffect effect) Drop;
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
	
	public HResult Drop(/*IDataObject*/ IUnknown* dataObject, uint32 grfKeyState, int2 point, ref DropEffect effect) mut
	{
		return VT.Drop(&this, dataObject, grfKeyState, point, ref effect);
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
	public abstract Result<DropEffect> OnDrop(int2 cursorPosition);

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
	
	[CallingConvention(.Stdcall)]
	private static HResult DropImpl(IDropTarget* self, /*IDataObject*/ IUnknown* dataObject, uint32 grfKeyState, int2 point, ref DropEffect effect)
	{
		Self instance = GetInstance(self);
		Result<DropEffect> result = instance.OnDrop(point);

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

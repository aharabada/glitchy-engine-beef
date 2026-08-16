#if BF_PLATFORM_WINDOWS

using System;
using DirectX.Common;

namespace GlitchyEditor.Platform.Windows.Com;

static
{
	[Import("Ole32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern HResult GetRunningObjectTable(uint32 reserved, out IRunningObjectTable* runningObjectTable);
	[Import("Ole32.lib"), CLink, CallingConvention(.Stdcall)]
	public static extern HResult CreateBindCtx(uint32 reserved, out IBindCtx* bindCtx);
}

/// Opaque, only ever passed along as a pointer (e.g. to IMoniker.GetDisplayName).
[CRepr]
public struct IBindCtx : IUnknown
{
	public const new Guid IID = .(0x0000000e, 0x0000, 0x0000, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46);
}

[CRepr]
public struct IMoniker : IUnknown
{
	public const new Guid IID = .(0x0000000f, 0x0000, 0x0000, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46);

	public new VTable* VT { get => (.)mVT; }

	/// The returned display name must be freed with CoTaskMemFree.
	public HResult GetDisplayName(IBindCtx* bindCtx, IMoniker* monikerToLeft, out char16* displayName) mut =>
		VT.GetDisplayName(&this, bindCtx, monikerToLeft, out displayName);

	[CRepr]
	public struct VTable : IUnknown.VTable
	{
		// IMoniker inherits IPersistStream (which inherits IPersist). We only need GetDisplayName,
		// all other slots are placeholders that keep the layout correct.
		public void* GetClassID;			// IPersist
		public void* IsDirty;				// IPersistStream
		public void* Load;
		public void* Save;
		public void* GetSizeMax;
		public void* BindToObject;			// IMoniker
		public void* BindToStorage;
		public void* Reduce;
		public void* ComposeWith;
		public void* Enum;
		public void* IsEqual;
		public void* Hash;
		public void* IsRunning;
		public void* GetTimeOfLastChange;
		public void* Inverse;
		public void* CommonPrefixWith;
		public void* RelativePathTo;
		public function [CallingConvention(.Stdcall)] HResult(IMoniker* self, IBindCtx* bindCtx, IMoniker* monikerToLeft, out char16* displayName) GetDisplayName;
		// ParseDisplayName and IsSystemMoniker follow but are never called.
	}
}

[CRepr]
public struct IEnumMoniker : IUnknown
{
	public const new Guid IID = .(0x00000102, 0x0000, 0x0000, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46);

	public new VTable* VT { get => (.)mVT; }

	/// Returns S_OK if an element was fetched, S_FALSE if the enumeration is exhausted.
	public HResult Next(uint32 count, out IMoniker* monikers, out uint32 fetchedCount) mut =>
		VT.Next(&this, count, out monikers, out fetchedCount);

	[CRepr]
	public struct VTable : IUnknown.VTable
	{
		public function [CallingConvention(.Stdcall)] HResult(IEnumMoniker* self, uint32 count, out IMoniker* monikers, out uint32 fetchedCount) Next;
		public void* Skip;
		public void* Reset;
		public void* Clone;
	}
}

[CRepr]
public struct IRunningObjectTable : IUnknown
{
	public const new Guid IID = .(0x00000010, 0x0000, 0x0000, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46);

	public new VTable* VT { get => (.)mVT; }

	public HResult GetObject(IMoniker* objectName, out IUnknown* outObject) mut =>
		VT.GetObject(&this, objectName, out outObject);
	public HResult EnumRunning(out IEnumMoniker* enumMoniker) mut =>
		VT.EnumRunning(&this, out enumMoniker);

	[CRepr]
	public struct VTable : IUnknown.VTable
	{
		public void* Register;
		public void* Revoke;
		public void* IsRunning;
		public function [CallingConvention(.Stdcall)] HResult(IRunningObjectTable* self, IMoniker* objectName, out IUnknown* outObject) GetObject;
		public void* NoteChangeTime;
		public void* GetTimeOfLastChange;
		public function [CallingConvention(.Stdcall)] HResult(IRunningObjectTable* self, out IEnumMoniker* enumMoniker) EnumRunning;
	}
}

#endif

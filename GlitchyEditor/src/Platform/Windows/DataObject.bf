using System;
using DirectX.Common;
using GlitchyEngine.Platform.Windows.Com;

namespace GlitchyEditor.Platform.Windows;

[CRepr]
public struct IDataObject : IUnknown
{
	public const new Guid IID = .(0x0000010e, 0x0000, 0x0000, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46);
	
	public new VTable* VT { get => (.)mVT; }
	
	public HResult GetData(ref FORMATETC pformatetcIn, out STGMEDIUM pmedium) mut => VT.GetData(&this, ref pformatetcIn, out pmedium);
	public HResult GetDataHere(ref FORMATETC pformatetc, out STGMEDIUM pmedium) mut => VT.GetDataHere(&this, ref pformatetc, out pmedium);
	public HResult QueryGetData(ref FORMATETC pformatetc) mut => VT.QueryGetData(&this, ref pformatetc);
	public HResult GetCanonicalFormatEtc(ref FORMATETC pformatectIn, out FORMATETC pformatetcOut) mut => VT.GetCanonicalFormatEtc(&this, ref pformatectIn, out pformatetcOut);
	public HResult SetData(ref FORMATETC pformatetc, ref STGMEDIUM pmedium, BigBool fRelease) mut => VT.SetData(&this, ref pformatetc, ref pmedium, fRelease);
	public HResult EnumFormatEtc(uint32 dwDirection, out /*IEnumFORMATETC*/ IUnknown* ppenumFormatEtc) mut => VT.EnumFormatEtc(&this, dwDirection, out ppenumFormatEtc);
	public HResult DAdvise(ref FORMATETC pformatetc, uint32 advf, ref /*IAdviseSink*/ IUnknown* pAdvSink, out uint32 pdwConnection) mut => VT.DAdvise(&this, ref pformatetc, advf, ref pAdvSink, out pdwConnection);
	public HResult DUnadvise(uint32 dwConnection) mut => VT.DUnadvise(&this, dwConnection);
	public HResult EnumDAdvise(out /*IEnumSTATDATA*/ IUnknown* ppenumAdvise) mut => VT.EnumDAdvise(&this, out ppenumAdvise);

	[CRepr]
	public struct VTable : IUnknown.VTable
	{
		public new function [CallingConvention(.Stdcall)] HResult(IDataObject* self, ref FORMATETC pformatetcIn, out STGMEDIUM pmedium) GetData;
		public new function [CallingConvention(.Stdcall)] HResult(IDataObject* self, ref FORMATETC pformatetc, out STGMEDIUM pmedium) GetDataHere;
		public new function [CallingConvention(.Stdcall)] HResult(IDataObject* self, ref FORMATETC pformatetc) QueryGetData;
		public new function [CallingConvention(.Stdcall)] HResult(IDataObject* self, ref FORMATETC pformatectIn, out FORMATETC pformatetcOut) GetCanonicalFormatEtc;
		public new function [CallingConvention(.Stdcall)] HResult(IDataObject* self, ref FORMATETC pformatetc, ref STGMEDIUM pmedium, BigBool fRelease) SetData;
		public new function [CallingConvention(.Stdcall)] HResult(IDataObject* self, uint32 dwDirection, out /*IEnumFORMATETC*/ IUnknown* ppenumFormatEtc) EnumFormatEtc;
		public new function [CallingConvention(.Stdcall)] HResult(IDataObject* self, ref FORMATETC pformatetc, uint32 advf, ref /*IAdviseSink*/ IUnknown* pAdvSink, out uint32 pdwConnection) DAdvise;
		public new function [CallingConvention(.Stdcall)] HResult(IDataObject* self, uint32 dwConnection) DUnadvise;
		public new function [CallingConvention(.Stdcall)] HResult(IDataObject* self, out /*IEnumSTATDATA*/ IUnknown* ppenumAdvise) EnumDAdvise;
	}
}

abstract class IDataObjectImplBase : IUnknownImplBase<IDataObject, IDataObject.VTable>
{
	protected override void InitVTable(ref IDataObject.VTable vTable)
	{
		vTable.GetData = => GetDataImpl;
		vTable.GetDataHere = => GetDataHereImpl;
		vTable.QueryGetData = => QueryGetDataImpl;
		vTable.GetCanonicalFormatEtc = => GetCanonicalFormatEtcImpl;
		vTable.SetData = => SetDataImpl;
		vTable.EnumFormatEtc = => EnumFormatEtcImpl;
		vTable.DAdvise = => DAdviseImpl;
		vTable.DUnadvise = => DUnadviseImpl;
		vTable.EnumDAdvise = => EnumDAdviseImpl;
	}

	[CallingConvention(.Stdcall)]
	private static HResult GetDataImpl(IDataObject* self, ref FORMATETC pformatetcIn, out STGMEDIUM pmedium)
	{
		Self instance = GetInstance<Self>(self);
		return instance.GetData(ref pformatetcIn, out pmedium);
	}

	[CallingConvention(.Stdcall)]
	private static HResult GetDataHereImpl(IDataObject* self, ref FORMATETC pformatetc, out STGMEDIUM pmedium)
	{
		Self instance = GetInstance<Self>(self);
		return instance.GetDataHere(ref pformatetc, out pmedium);
	}

	[CallingConvention(.Stdcall)]
	private static HResult QueryGetDataImpl(IDataObject* self, ref FORMATETC pformatetc)
	{
		Self instance = GetInstance<Self>(self);
		return instance.QueryGetData(ref pformatetc);
	}

	[CallingConvention(.Stdcall)]
	private static HResult GetCanonicalFormatEtcImpl(IDataObject* self, ref FORMATETC pformatectIn, out FORMATETC pformatetcOut)
	{
		Self instance = GetInstance<Self>(self);
		return instance.GetCanonicalFormatEtc(ref pformatectIn, out pformatetcOut);
	}

	[CallingConvention(.Stdcall)]
	private static HResult SetDataImpl(IDataObject* self, ref FORMATETC pformatetc, ref STGMEDIUM pmedium, BigBool fRelease)
	{
		Self instance = GetInstance<Self>(self);
		return instance.SetData(ref pformatetc, ref pmedium, fRelease);
	}

	[CallingConvention(.Stdcall)]
	private static HResult EnumFormatEtcImpl(IDataObject* self, uint32 dwDirection, out IUnknown* ppenumFormatEtc)
	{
		Self instance = GetInstance<Self>(self);
		return instance.EnumFormatEtc(dwDirection, out ppenumFormatEtc);
	}

	[CallingConvention(.Stdcall)]
	private static HResult DAdviseImpl(IDataObject* self, ref FORMATETC pformatetc, uint32 advf, ref IUnknown* pAdvSink, out uint32 pdwConnection)
	{
		Self instance = GetInstance<Self>(self);
		return instance.DAdvise(ref pformatetc, advf, ref pAdvSink, out pdwConnection);
	}

	[CallingConvention(.Stdcall)]
	private static HResult DUnadviseImpl(IDataObject* self, uint32 dwConnection)
	{
		Self instance = GetInstance<Self>(self);
		return instance.DUnadvise(dwConnection);
	}

	[CallingConvention(.Stdcall)]
	private static HResult EnumDAdviseImpl(IDataObject* self, out IUnknown* ppenumAdvise)
	{
		Self instance = GetInstance<Self>(self);
		return instance.EnumDAdvise(out ppenumAdvise);
	}

	// Abstract methods to be implemented by derived classes
	public abstract HResult GetData(ref FORMATETC pformatetcIn, out STGMEDIUM pmedium);
	public abstract HResult GetDataHere(ref FORMATETC pformatetc, out STGMEDIUM pmedium);
	public abstract HResult QueryGetData(ref FORMATETC pformatetc);
	public abstract HResult GetCanonicalFormatEtc(ref FORMATETC pformatectIn, out FORMATETC pformatetcOut);
	public abstract HResult SetData(ref FORMATETC pformatetc, ref STGMEDIUM pmedium, BigBool fRelease);
	public abstract HResult EnumFormatEtc(uint32 dwDirection, out IUnknown* ppenumFormatEtc);
	public abstract HResult DAdvise(ref FORMATETC pformatetc, uint32 advf, ref IUnknown* pAdvSink, out uint32 pdwConnection);
	public abstract HResult DUnadvise(uint32 dwConnection);
	public abstract HResult EnumDAdvise(out IUnknown* ppenumAdvise);
}

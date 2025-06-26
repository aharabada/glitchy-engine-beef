#if BF_PLATFORM_WINDOWS

using System;
using DirectX.Common;
using GlitchyEngine.Platform.Windows.Com;

namespace GlitchyEditor.Platform.Windows;

[CRepr]
public struct IDropSource : IUnknown
{
	public const new Guid IID = .(0x00000121, 0x0000, 0x0000, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46);
	
	public new VTable* VT { get => (.)mVT; }
	
	public HResult QueryContinueDrag(BigBool fEscapePressed, uint32 grfKeyState) mut => VT.QueryContinueDrag(&this, fEscapePressed, grfKeyState);
	public HResult GiveFeedback(DropEffect dwEffect) mut => VT.GiveFeedback(&this, dwEffect);

	[CRepr]
	public struct VTable : IUnknown.VTable
	{
		public new function [CallingConvention(.Stdcall)] HResult(IDropSource* self, BigBool fEscapePressed, uint32 grfKeyState) QueryContinueDrag;
		public new function [CallingConvention(.Stdcall)] HResult(IDropSource* self, DropEffect dwEffect) GiveFeedback;
	}
}

abstract class IDropSourceImplBase : IUnknownImplBase<IDropSource, IDropSource.VTable>
{
	protected override void InitVTable(ref IDropSource.VTable vTable)
	{
		vTable.QueryContinueDrag = => QueryContinueDragImpl;
		vTable.GiveFeedback = => GiveFeedbackImpl;
	}

	[CallingConvention(.Stdcall)]
	private static HResult QueryContinueDragImpl(IDropSource* self, BigBool fEscapePressed, uint32 grfKeyState)
	{
		Self instance = GetInstance<Self>(self);

		// TODO: Translate keyStates (MK_CONTROL, etc...)

		if (instance.QueryContinueDrag(fEscapePressed, grfKeyState) case .Ok)
		{
			return .S_OK;
		}

		return .E_FAIL;
	}

	[CallingConvention(.Stdcall)]
	private static HResult GiveFeedbackImpl(IDropSource* self, DropEffect effect)
	{
		Self instance = GetInstance<Self>(self);
		
		if (instance.GiveFeedback(effect) case .Ok)
		{
			return .S_OK;
		}

		return .E_FAIL;
	}
	
	public abstract Result<void> QueryContinueDrag(bool escapePressed, uint32 grfKeyState);
	public abstract Result<void> GiveFeedback(DropEffect effect);
}

class MyDropSource : IDropSourceImplBase
{
	public override Result<void> QueryContinueDrag(bool escapePressed, uint32 grfKeyState)
	{
		Runtime.NotImplemented();
	}

	public override Result<void> GiveFeedback(DropEffect effect)
	{
		Runtime.NotImplemented();
	}
}

#endif

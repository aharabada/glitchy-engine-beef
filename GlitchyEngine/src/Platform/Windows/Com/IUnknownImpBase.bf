using System;
using DirectX.Common;
using GlitchyEngine.Core;
using System.Diagnostics;

namespace GlitchyEngine.Platform.Windows.Com;

/// Base class for implementation of an COM-Interface using a Beef-Class.
abstract class IUnknownImplBase<TInterface, TVTable> : RefCounter where TInterface : IUnknown, struct where TVTable : IUnknown.VTable
{
	[CRepr]
	protected struct InterfaceImpl<TInterface>
	{
		public TInterface Base;
		public void* ClassPtr;
	}

	InterfaceImpl<TInterface> impl;

	private static TVTable vTable;

	public TInterface* InterfacePtr => (TInterface*)&impl;

	public this()
	{
		impl = .();
		impl.Base.[Friend]mVT = (IUnknown.VTable*)&vTable;
		impl.ClassPtr = Internal.UnsafeCastToPtr(this);

		if (vTable.QueryInterface == null)
		{
			vTable.QueryInterface = => QueryInterfaceImpl;
			vTable.AddRef = => AddRefImpl;
			vTable.Release = => ReleaseImpl;
	
			InitVTable(ref vTable);
		}
	}

	protected abstract void InitVTable(ref TVTable vTable);

	/// Get the beef instance from the interface.
	protected static T GetInstance<T>(IUnknown* self) where T : class
	{
		InterfaceImpl<TInterface>* impl = (.)self;

		Object beefInstance = Internal.UnsafeCastToObject(impl.ClassPtr);

		Debug.Assert(beefInstance is T);
		
		return (T)beefInstance;
	}
	
	[CallingConvention(.Stdcall)]
	private static HResult QueryInterfaceImpl(IUnknown* self, ref Guid riid, void** output)
	{
		Self instance = GetInstance<Self>(self);

		HResult result = .E_NOINTERFACE;
		*output = null;

		if (riid == IUnknown.IID || riid == TInterface.IID) 
		{
			*output = (IUnknown*)&instance.impl;
			instance.AddRef();
			result = .S_OK;
		}

		return result;
	}

	[CallingConvention(.Stdcall)]
	private static uint32 AddRefImpl(IUnknown* self)
	{
		Self instance = GetInstance<Self>(self);

		instance.AddRef();
		return (uint32)instance.RefCount;
	}

	[CallingConvention(.Stdcall)]
	private static uint32 ReleaseImpl(IUnknown* self)
	{
		Self instance = GetInstance<Self>(self);

		uint32 count = (uint32)instance.ReleaseRefNoDelete();

		if (count == 0)
			delete instance;

		return count;
	}
}

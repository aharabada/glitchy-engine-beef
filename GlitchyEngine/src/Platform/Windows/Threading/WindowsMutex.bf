#if BF_PLATFORM_WINDOWS

using static System.Windows;

namespace GlitchyEngine.Threading
{
	extension Mutex
	{
		internal Handle nativeHandle;

		public this(bool initialyOwned = false)
		{
			nativeHandle = CreateMutexW(null, initialyOwned, null);
			
			Log.EngineLogger.AssertDebug(nativeHandle != 0, scope $"Failed to create mutex. Error code: {GetLastError()}");
		}

		public ~this()
		{
			CloseHandle(nativeHandle);
		}

		public override LockResult Lock(uint32 timeout = InfiniteTimeout)
		{
			int i = WaitForSingleObject(nativeHandle, timeout);

			switch(i)
			{
			case 0x00000000L:
				return .Released;
			case 0x00000080L:
				return .Abandoned;
			case 0x00000102L:
				return .Timeout;
			case 0xFFFFFFFF:
				return .Failed;
			default:
				return .Unknown;
			}
		}

		public bool Unlock()
		{
			return ReleaseMutex(nativeHandle);
		}
	}
}

#endif

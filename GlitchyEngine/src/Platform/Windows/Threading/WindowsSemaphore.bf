#if BF_PLATFORM_WINDOWS

using static System.Windows;

namespace GlitchyEngine.Threading
{
	extension Semaphore
	{
		internal Handle nativeHandle;

		public override this(int32 initialCount = 1, int32 maximumCount = 1)
		{
			nativeHandle = (.)CreateSemaphoreW(null, initialCount, maximumCount, null);
			
			Log.EngineLogger.AssertDebug(nativeHandle != 0, scope $"Failed to create semaphore. Error code: {GetLastError()}");
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

		public bool Unlock(int32 releaseCount = 1)
		{
			return ReleaseSemaphore(nativeHandle, releaseCount, null);
		}

		public bool Unlock(out int32 previousCount, int32 releaseCount = 1)
		{
			previousCount = ?;
			return ReleaseSemaphore(nativeHandle, releaseCount, &previousCount);
		}
	}
}

#endif
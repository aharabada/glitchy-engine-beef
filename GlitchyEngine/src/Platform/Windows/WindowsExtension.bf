namespace System
{
	extension Windows
	{
		public struct SecurityAttributes
		{
			public uint32 Length;
			public SECURITY_DESCRIPTOR* SecurityDescriptor;
			public IntBool InheritHandle;
		}

		[LinkName(.C)]
		public static extern Windows.Handle CreateSemaphoreW(SecurityAttributes* semaphoreAttributes, int32 initialCount, int32 maximumCount, char16* name);

		[LinkName(.C)]
		public static extern uint32 WaitForSingleObject(Handle handle, uint32 timeout);

		[LinkName(.C)]
		public static extern uint32 WaitForMultipleObjects(uint32 count, Handle *handles, IntBool bWaitAll, uint32 timeout);

		public const uint32 InfiniteTimeout = 0xFFFFFFFF;

		[Inline]
		public static uint32 WaitForMultipleObjects(Handle[] handles, bool waitForAll, uint32 timeout = InfiniteTimeout)
		{
			return WaitForMultipleObjects((.)handles.Count, handles.CArray(), waitForAll, timeout);
		}

		[LinkName(.C)]
		public static extern IntBool ReleaseSemaphore(Handle semaphore, int32 releaseCount, int32* previousCount);

		[LinkName(.C)]
		public static extern Handle CreateMutexW(SecurityAttributes* mutexAttributes, IntBool initialOwner, char16* name);

		[LinkName(.C)]
		public static extern IntBool ReleaseMutex(Handle mutex);
	}
}

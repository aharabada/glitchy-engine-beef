namespace GlitchyEngine.Threading
{
	public class Semaphore
	{
		public extern this(int32 initialCount = 1, int32 maximumCount = 1);

		public const uint32 InfiniteTimeout = 0xFFFFFFFF;

		public extern LockResult Lock(uint32 timeout = InfiniteTimeout);

		public extern bool Unlock(int32 releaseCount = 1);

		public extern bool Unlock(out int32 previousCount, int32 releaseCount = 1);
	}
}
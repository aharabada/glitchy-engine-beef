namespace GlitchyEngine.Threading
{
	public class Mutex
	{
		public extern this(bool initialyOwned = false);
		
		public const uint32 InfiniteTimeout = 0xFFFFFFFF;

		public extern LockResult Lock(uint32 timeout = InfiniteTimeout);

		public extern bool Unlock();
	}
}

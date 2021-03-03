namespace GlitchyEngine.Threading
{
	public enum LockResult
	{
		/**
		 * The lock was released by the owning thread.
		 */
		Released,
		/**
		 * The owning thread terminated without releasing the lock.
		 */
		Abandoned,
		/**
		 * The lock function timed out.
		 */
		Timeout,
		/**
		 * The function has failed.
		 */
		Failed,
		
		Unknown
	}
}

using System;

namespace GlitchyEngine.Core
{
	/**
	 * Provides a reference counter that, when reaching 0, automatically deletes itself.
	 * Implements the IDisposable interface so that it can be used with a using-Block so that the counter
	 * will be decremented automatically after leaving the block.
	 */
	public class RefCounter : System.RefCounted, IDisposable
	{
		protected ~this()
		{

		}

		public void Dispose()
		{
			ReleaseRef();
		}
	}
}

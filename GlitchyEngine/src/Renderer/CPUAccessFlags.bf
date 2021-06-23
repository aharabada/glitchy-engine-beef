namespace GlitchyEngine.Renderer
{
	/**
	 * Defines how the CPU can access a resource.
	 */
	public enum CPUAccessFlags
	{
		/// The CPU has no access to the resource.
		None = 0,
		/// The CPU has read access to the resource.
		Read = 1,
		/// The CPU has write access to the resource.
		Write = 2
	}

}

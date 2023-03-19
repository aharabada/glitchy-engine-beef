namespace GlitchyEngine.World
{
	/// Provides a mechanism for a component to release resources once it is being removed.
	public interface IDisposableComponent
	{
		/** @brief Disposes of the data of the given component.
		 * @Note This function will be called when the given component was removed from the entity
		 * 		or when the entity itself was removed.
		 */
		void Dispose() mut;
	}
}
